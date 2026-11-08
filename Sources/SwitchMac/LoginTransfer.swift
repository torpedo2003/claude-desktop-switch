import Foundation
import CommonCrypto
import CryptoKit
import SQLite3
import SwitchCore
import SwitchStorage

public struct TransferImport: Sendable {
    public var library: LibraryState
    public var importedAccountIDs: Set<String> = []
    public var skipped = 0
    public var failed = 0
}

/// Moves saved logins between Macs. Each Mac's Claude encrypts its secrets under its own Safe Storage password.
/// Export re-encrypts them under a random password for this file, so the Mac's own password never leaves it,
/// and import re-encrypts them for the local Mac.
enum LoginTransfer {
    private static let magic = Data("CSWTRANSFER1\n".utf8)
    private static let iterations: UInt32 = 600_000
    private static let chunkLimit = 256 * 1024 * 1024
    private static var damaged: SwitchError { .blocked(L10n.tr("Wrong password, or this file is damaged.")) }

    private struct Manifest: Codable {
        var library: LibraryState
        var transportPassword: Data
    }

    // MARK: File format

    private static func key(passphrase: String, salt: Data) throws -> SymmetricKey {
        let secret = Data(passphrase.precomposedStringWithCanonicalMapping.utf8)
        var output = Data(count: 32)
        let length = output.count
        let status = output.withUnsafeMutableBytes { output in
            secret.withUnsafeBytes { secret in salt.withUnsafeBytes { salt in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), secret.bindMemory(to: Int8.self).baseAddress, secret.count,
                    salt.bindMemory(to: UInt8.self).baseAddress, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                    output.bindMemory(to: UInt8.self).baseAddress, length)
            } }
        }
        guard status == kCCSuccess else { throw damaged }
        return SymmetricKey(data: output)
    }
    /// Binds a chunk to its place in this file, so chunks cannot be dropped, reordered or spliced from another file.
    private static func context(salt: Data, index: UInt32, count: UInt32) -> Data {
        salt + bigEndian(index) + bigEndian(count)
    }
    private static func bigEndian(_ value: UInt32) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }
    private static func number(_ data: Data) -> UInt32 { data.reduce(0) { $0 << 8 | UInt32($1) } }

    private static func randomBytes(_ count: Int) throws -> Data {
        var bytes = Data(count: count)
        guard bytes.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }) == errSecSuccess else {
            throw SwitchError.blocked(L10n.tr("Could not securely save the account data. Please try again."))
        }
        return bytes
    }
    private static func readExactly(_ handle: FileHandle, _ count: Int) throws -> Data {
        guard let data = try handle.read(upToCount: count), data.count == count else { throw damaged }
        return data
    }
    /// Visits every chunk in order and fails if the file is altered, cut short or has trailing data.
    static func read(_ url: URL, passphrase: String, body: (UInt32, Data) async throws -> Void) async throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard try readExactly(handle, magic.count) == magic else { throw damaged }
        let salt = try readExactly(handle, 16)
        guard number(try readExactly(handle, 4)) == iterations else { throw damaged }
        let count = number(try readExactly(handle, 4))
        guard count > 0 else { throw damaged }
        let key = try key(passphrase: passphrase, salt: salt)
        for index in 0..<count {
            let size = Int(number(try readExactly(handle, 4)))
            guard size <= chunkLimit else { throw damaged }
            let sealed = try readExactly(handle, size)
            let plain: Data
            do { plain = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key, authenticating: context(salt: salt, index: index, count: count)) }
            catch { throw damaged }
            try await body(index, plain)
        }
        guard try handle.read(upToCount: 1)?.isEmpty ?? true else { throw damaged }
    }

    // MARK: Export

    /// Returns how many accounts were written. A saved login that can no longer be read or converted is left out.
    static func export(library: LibraryState, vault: CredentialVault, safeStoragePassword: Data,
                       passphrase: String, to destination: URL) async throws -> Int {
        var local = try SafeStorageCipher(password: safeStoragePassword)
        let transportPassword = try randomBytes(32)
        var transport = try SafeStorageCipher(password: transportPassword)
        defer { local.wipe(); transport.wipe() }
        func portable(_ id: String) async throws -> LoginSnapshot {
            try transcrypt(try await vault.load(accountID: id), from: local, to: transport)
        }
        var ids: [String] = []
        for id in try await vault.accountIDs() where (try? await portable(id)) != nil { ids.append(id) }
        let salt = try randomBytes(16)
        let key = try key(passphrase: passphrase, salt: salt), count = UInt32(ids.count + 1)
        let partial = destination.deletingLastPathComponent().appendingPathComponent("." + UUID().uuidString + ".partial")
        let fd = open(partial.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw SwitchError.unsafePath }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            func write(_ plain: Data, index: UInt32) throws {
                guard let sealed = try AES.GCM.seal(plain, using: key, authenticating: context(salt: salt, index: index, count: count)).combined,
                      sealed.count <= chunkLimit else {
                    throw SwitchError.blocked(L10n.tr("Account data is too large to save. Nothing was changed."))
                }
                try handle.write(contentsOf: bigEndian(UInt32(sealed.count)) + sealed)
            }
            try handle.write(contentsOf: magic + salt + bigEndian(iterations) + bigEndian(count))
            var movedLibrary = library
            movedLibrary.newAccountFollowUp = nil
            try write(JSONEncoder().encode(Manifest(library: movedLibrary, transportPassword: transportPassword)), index: 0)
            for (offset, id) in ids.enumerated() {
                try write(JSONEncoder().encode(try await portable(id)), index: UInt32(offset + 1))
            }
            try handle.synchronize()
            try handle.close()
            guard rename(partial.path, destination.path) == 0 else { throw SwitchError.unsafePath }
            return ids.count
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
    }

    // MARK: Import

    /// The whole file is verified first, so a damaged file adds nothing to the vault.
    static func importFile(_ url: URL, passphrase: String, vault: CredentialVault, safeStoragePassword: Data) async throws -> TransferImport {
        try await read(url, passphrase: passphrase) { _, _ in }
        var manifest: Manifest?, source: SafeStorageCipher?
        var target = try SafeStorageCipher(password: safeStoragePassword)
        defer { target.wipe(); source?.wipe() }
        var result = TransferImport(library: LibraryState())
        try await read(url, passphrase: passphrase) { index, plain in
            if index == 0 {
                guard let decoded = try? JSONDecoder().decode(Manifest.self, from: plain) else { throw damaged }
                manifest = decoded; source = try SafeStorageCipher(password: decoded.transportPassword)
                return
            }
            guard let source, let snapshot = try? JSONDecoder().decode(LoginSnapshot.self, from: plain) else { result.failed += 1; return }
            if await vault.contains(accountID: snapshot.accountID) { result.skipped += 1; return }
            do {
                try await vault.save(try transcrypt(snapshot, from: source, to: target))
                result.importedAccountIDs.insert(snapshot.accountID)
            } catch { result.failed += 1 }
        }
        guard let manifest else { throw damaged }
        result.library = manifest.library
        return result
    }

    static func transcrypt(_ snapshot: LoginSnapshot, from source: SafeStorageCipher, to target: SafeStorageCipher) throws -> LoginSnapshot {
        var result = snapshot
        for key in ["oauth:tokenCache", "oauth:tokenCacheV2"] {
            guard let value = snapshot.auth[key]?.string, !value.isEmpty else { continue }
            guard let encrypted = Data(base64Encoded: value) else { throw SafeStorageCipher.Failure() }
            let plain = try source.decrypt(encrypted)
            // Padding alone can pass under the wrong key; the cache is always a JSON object.
            guard (try? JSONDecoder().decode(JSONValue.self, from: plain).object) != nil else { throw SafeStorageCipher.Failure() }
            result.auth[key] = .string(try target.encrypt(plain).base64EncodedString())
        }
        guard let cookies = snapshot.files.first(where: { $0.path == "Cookies" }) else { throw SafeStorageCipher.Failure() }
        func companion(_ suffix: String) -> Data? { snapshot.files.first { $0.path == "Cookies" + suffix }?.data }
        let rewritten = try rewriteCookies(cookies.data, wal: companion("-wal"), journal: companion("-journal"), from: source, to: target)
        result.files = snapshot.files.filter { !["Cookies", "Cookies-wal", "Cookies-shm", "Cookies-journal"].contains($0.path) }
        result.files.append(ArchiveFile(path: "Cookies", data: rewritten, sha256: digest(rewritten)))
        return result
    }

    /// Works on a private copy and folds any WAL into a single database file.
    private static func rewriteCookies(_ data: Data, wal: Data?, journal: Data?, from source: SafeStorageCipher, to target: SafeStorageCipher) throws -> Data {
        var template = Array(FileManager.default.temporaryDirectory.appendingPathComponent("switch-transfer-XXXXXX").path.utf8CString)
        guard mkdtemp(&template) != nil else { throw SwitchError.unsafePath }
        let folder = URL(fileURLWithPath: String(cString: template))
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Cookies")
        try data.write(to: file)
        if let wal, !wal.isEmpty { try wal.write(to: folder.appendingPathComponent("Cookies-wal")) }
        if let journal, !journal.isEmpty { try journal.write(to: folder.appendingPathComponent("Cookies-journal")) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(file.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db); throw SafeStorageCipher.Failure()
        }
        do {
            func run(_ sql: String) throws { guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw SafeStorageCipher.Failure() } }
            func prepare(_ sql: String) throws -> OpaquePointer? {
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw SafeStorageCipher.Failure() }
                return statement
            }
            try run("BEGIN IMMEDIATE")
            let select = try prepare("SELECT rowid, encrypted_value FROM cookies WHERE length(encrypted_value) > 0")
            defer { sqlite3_finalize(select) }
            let update = try prepare("UPDATE cookies SET encrypted_value = ? WHERE rowid = ?")
            defer { sqlite3_finalize(update) }
            var rows: [(Int64, Data)] = []
            step: while true {
                switch sqlite3_step(select) {
                case SQLITE_ROW:
                    let bytes = sqlite3_column_blob(select, 1), size = Int(sqlite3_column_bytes(select, 1))
                    guard let bytes else { throw SafeStorageCipher.Failure() }
                    rows.append((sqlite3_column_int64(select, 0), Data(bytes: bytes, count: size)))
                case SQLITE_DONE: break step
                default: throw SafeStorageCipher.Failure()
                }
            }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (rowid, encrypted) in rows {
                let value = try target.encrypt(try source.decrypt(encrypted))
                sqlite3_reset(update)
                _ = value.withUnsafeBytes { sqlite3_bind_blob(update, 1, $0.baseAddress, Int32(value.count), transient) }
                sqlite3_bind_int64(update, 2, rowid)
                guard sqlite3_step(update) == SQLITE_DONE else { throw SafeStorageCipher.Failure() }
            }
            try run("COMMIT")
        } catch { sqlite3_close(db); throw error }
        // Folds the WAL in. A WAL-mode header with no WAL beside it cannot be opened read-only, as LoginProbe does.
        let folded = sqlite3_exec(db, "PRAGMA journal_mode=DELETE", nil, nil, nil)
        guard sqlite3_close(db) == SQLITE_OK, folded == SQLITE_OK else { throw SafeStorageCipher.Failure() }
        return try Data(contentsOf: file)
    }

    // MARK: Library

    /// Local information wins for accounts this Mac already knows; `hasSnapshot` is set from what the vault now holds.
    static func merge(into local: LibraryState, imported: TransferImport) -> LibraryState {
        var state = local
        for account in imported.library.accounts {
            let saved = imported.importedAccountIDs.contains(account.id)
            if let index = state.accounts.firstIndex(where: { $0.id == account.id }) {
                guard saved else { continue }
                state.accounts[index].hasSnapshot = true
                state.accounts[index].lastSavedAt = account.lastSavedAt
                state.accounts[index].snapshotFingerprint = nil
            } else {
                var added = account
                added.hasSnapshot = saved
                added.snapshotFingerprint = nil
                state.accounts.append(added)
            }
            state.usage[account.id] = state.usage[account.id] ?? imported.library.usage[account.id]
            state.usageHistory[account.id] = state.usageHistory[account.id] ?? imported.library.usageHistory[account.id]
        }
        let known = Set(state.follows.map(\.id))
        state.follows += imported.library.follows.filter { !known.contains($0.id) }
        state.preferences = imported.library.preferences
        return state
    }
}

public extension TransferImport {
    func merged(into local: LibraryState) -> LibraryState { LoginTransfer.merge(into: local, imported: self) }
}
