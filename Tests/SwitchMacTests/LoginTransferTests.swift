import XCTest
import SQLite3
import SwitchCore
import SwitchStorage
@testable import SwitchMac

final class LoginTransferTests: XCTestCase {
    private let first = "0a1b2c3d-1111-4aaa-8bbb-000000000001", second = "0a1b2c3d-1111-4aaa-8bbb-000000000002"
    private let passphrase = "fixture-transfer-passphrase"
    private let oldPassword = Data("old-mac-safe-storage".utf8), newPassword = Data("new-mac-safe-storage".utf8)
    private let tokens = Data(#"{"fixture":{"token":"synthetic"}}"#.utf8), cookieValue = Data("synthetic-session-value".utf8)

    private func directory() throws -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/transfer-file-fixtures/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func vault(_ root: URL, _ name: String) -> CredentialVault {
        CredentialVault(root: root.appendingPathComponent(name)) { _, _ in Data(repeating: 0x5a, count: 32) }
    }
    /// A signed-in cookie store whose only change sits in its WAL.
    private func cookies(in folder: URL, cipher: SafeStorageCipher) throws -> [ArchiveFile] {
        let url = folder.appendingPathComponent("source-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent("Cookies")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(file.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE cookies (host_key TEXT, name TEXT, expires_utc INTEGER, encrypted_value BLOB); PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0", nil, nil, nil), SQLITE_OK)
        let hex = try cipher.encrypt(cookieValue).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO cookies VALUES ('.claude.ai','sessionKey',0,x'\(hex)'), ('.claude.ai','other',0,x'')", nil, nil, nil), SQLITE_OK)
        return try ["Cookies", "Cookies-wal"].map { name in
            let data = try Data(contentsOf: url.appendingPathComponent(name))
            return ArchiveFile(path: name, data: data, sha256: digest(data))
        }
    }
    private func snapshot(_ id: String, in folder: URL, cipher: SafeStorageCipher) throws -> LoginSnapshot {
        LoginSnapshot(accountID: id, version: "0.14.2", createdAt: Date(),
            auth: ["lastKnownAccountUuid": .string(id), "oauth:tokenCacheV2": .string(try cipher.encrypt(tokens).base64EncodedString())],
            files: try cookies(in: folder, cipher: cipher), directories: ["Local Storage"])
    }
    private func library(_ ids: [String]) -> LibraryState {
        var state = LibraryState()
        state.accounts = ids.map { Account(id: $0, hasSnapshot: true, snapshotFingerprint: "old-mac") }
        state.preferences.maskEmail = true
        return state
    }
    private func storedCookie(_ snapshot: LoginSnapshot, in folder: URL) throws -> Data {
        let file = folder.appendingPathComponent("check-\(UUID().uuidString)")
        try XCTUnwrap(snapshot.files.first { $0.path == "Cookies" }).data.write(to: file)
        var db: OpaquePointer?, statement: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(file.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement); sqlite3_close(db) }
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT encrypted_value FROM cookies WHERE name='sessionKey'", -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        return Data(bytes: try XCTUnwrap(sqlite3_column_blob(statement, 0)), count: Int(sqlite3_column_bytes(statement, 0)))
    }

    func testRoundTripReencryptsTokensAndCookiesForTheNewMac() async throws {
        let root = try directory(), old = try SafeStorageCipher(password: oldPassword), new = try SafeStorageCipher(password: newPassword)
        let source = vault(root, "old"), target = vault(root, "new")
        try await source.save(snapshot(first, in: root, cipher: old))
        let file = root.appendingPathComponent("accounts.switchtransfer")
        let exported = try await LoginTransfer.export(library: library([first]), vault: source, safeStoragePassword: oldPassword, passphrase: passphrase, to: file)
        XCTAssertEqual(exported, 1)
        var manifest = Data()
        try await LoginTransfer.read(file, passphrase: passphrase) { index, plain in if index == 0 { manifest = plain } }
        XCTAssertFalse(manifest.isEmpty)
        XCTAssertNil(manifest.range(of: Data(oldPassword.base64EncodedString().utf8)), "The Mac's own password must stay on that Mac")

        let result = try await LoginTransfer.importFile(file, passphrase: passphrase, vault: target, safeStoragePassword: newPassword)
        XCTAssertEqual(result.importedAccountIDs, [first])
        let moved = try await target.load(accountID: first)
        let encrypted = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(moved.auth["oauth:tokenCacheV2"]?.string)))
        XCTAssertEqual(try new.decrypt(encrypted), tokens)
        XCTAssertNotEqual(try? old.decrypt(encrypted), tokens)

        XCTAssertEqual(moved.files.filter { $0.path.hasPrefix("Cookies") }.map(\.path), ["Cookies"])
        XCTAssertEqual(LoginProbe.signedIn(cookieData: try XCTUnwrap(moved.files.first { $0.path == "Cookies" }).data), true)
        let cookie = try storedCookie(moved, in: root)
        XCTAssertEqual(try new.decrypt(cookie), cookieValue)
        XCTAssertNotEqual(try? old.decrypt(cookie), cookieValue)
    }

    func testWrongPasswordAndAlteredFilesAddNothing() async throws {
        let root = try directory(), old = try SafeStorageCipher(password: oldPassword)
        let source = vault(root, "old"), target = vault(root, "new")
        try await source.save(snapshot(first, in: root, cipher: old))
        try await source.save(snapshot(second, in: root, cipher: old))
        let file = root.appendingPathComponent("accounts.switchtransfer")
        _ = try await LoginTransfer.export(library: library([first, second]), vault: source, safeStoragePassword: oldPassword, passphrase: passphrase, to: file)
        let data = try Data(contentsOf: file)

        func assertRejected(_ candidate: URL, passphrase: String) async throws {
            do {
                _ = try await LoginTransfer.importFile(candidate, passphrase: passphrase, vault: target, safeStoragePassword: newPassword)
                XCTFail("Expected rejection")
            } catch SwitchError.blocked {}
            let saved = try await target.accountIDs()
            XCTAssertEqual(saved, [], "A rejected file must add nothing")
        }
        try await assertRejected(file, passphrase: "not-the-right-passphrase")
        let truncated = root.appendingPathComponent("truncated")
        try data.dropLast(40).write(to: truncated)
        try await assertRejected(truncated, passphrase: passphrase)
        let trailing = root.appendingPathComponent("trailing")
        try (data + Data([0])).write(to: trailing)
        try await assertRejected(trailing, passphrase: passphrase)
        var flipped = data; flipped[flipped.count - 1] ^= 1
        let altered = root.appendingPathComponent("altered")
        try flipped.write(to: altered)
        try await assertRejected(altered, passphrase: passphrase)
    }

    func testExistingLoginIsKeptAndABadAccountDoesNotStopTheOthers() async throws {
        let root = try directory(), old = try SafeStorageCipher(password: oldPassword), wrong = try SafeStorageCipher(password: Data("another-mac".utf8))
        let new = try SafeStorageCipher(password: newPassword)
        let source = vault(root, "old"), target = vault(root, "new")
        let third = "0a1b2c3d-1111-4aaa-8bbb-000000000003"
        try await source.save(snapshot(first, in: root, cipher: old))
        try await source.save(snapshot(second, in: root, cipher: wrong))
        try await source.save(snapshot(third, in: root, cipher: old))
        let local = try snapshot(first, in: root, cipher: new)
        try await target.save(local)
        let before = try await target.generation(accountID: first)

        let file = root.appendingPathComponent("accounts.switchtransfer")
        let exported = try await LoginTransfer.export(library: library([first, second, third]), vault: source, safeStoragePassword: oldPassword, passphrase: passphrase, to: file)
        XCTAssertEqual(exported, 2, "A login that cannot be converted is left out of the file")
        let result = try await LoginTransfer.importFile(file, passphrase: passphrase, vault: target, safeStoragePassword: newPassword)

        XCTAssertEqual(result.importedAccountIDs, [third])
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.failed, 0)
        let after = try await target.generation(accountID: first)
        XCTAssertEqual(after.current, before.current)
        let containsFailed = await target.contains(accountID: second)
        XCTAssertFalse(containsFailed)
    }

    func testMergeKeepsLocalAccountsAndAddsNewOnes() {
        var local = LibraryState()
        var existing = Account(id: first, email: "ma•••ry@gmail.com", hasSnapshot: true, snapshotFingerprint: "local")
        existing.plan = "Max 5x"
        local.accounts = [existing]
        local.follows = [FollowRule(conversationID: "local-rule")]
        var incoming = library([first, second])
        incoming.accounts[0].email = "other•••@gmail.com"
        incoming.follows = [FollowRule(conversationID: "local-rule", targetAccountIDs: [second]), FollowRule(conversationID: "new-rule")]
        var outcome = TransferImport(library: incoming)
        outcome.importedAccountIDs = [second]

        let merged = outcome.merged(into: local)
        XCTAssertEqual(merged.accounts.map(\.id), [first, second])
        XCTAssertEqual(merged.accounts[0].email, existing.email)
        XCTAssertEqual(merged.accounts[0].snapshotFingerprint, "local")
        XCTAssertTrue(merged.accounts[1].hasSnapshot)
        XCTAssertNil(merged.accounts[1].snapshotFingerprint)
        XCTAssertEqual(merged.follows.map(\.id), ["local-rule", "new-rule"])
        XCTAssertTrue(merged.follows[0].targetAccountIDs.isEmpty)
        XCTAssertTrue(merged.preferences.maskEmail)
    }
}
