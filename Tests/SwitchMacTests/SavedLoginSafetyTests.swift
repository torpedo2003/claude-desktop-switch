import XCTest
import SQLite3
import SwitchCore
import SwitchStorage
@testable import SwitchMac

final class SavedLoginSafetyTests: XCTestCase {
    private let account = "0a1b2c3d-1111-4aaa-8bbb-000000000001"

    private func cache(cipherBytes: Int) -> JSONValue {
        .string((Data("v10".utf8) + Data(repeating: 0x41, count: cipherBytes)).base64EncodedString())
    }
    private func directory() -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/saved-login-fixtures/\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func vault(_ root: URL) -> CredentialVault {
        CredentialVault(root: root) { _, _ in Data(repeating: 0x5a, count: 32) }
    }
    private func snapshot(_ marker: String, cache: JSONValue) -> LoginSnapshot {
        LoginSnapshot(accountID: account, version: "0.14.2", createdAt: Date(),
                      auth: ["lastKnownAccountUuid": .string(account), "oauth:tokenCacheV2": cache],
                      files: [ArchiveFile(path: "Cookies", data: Data(marker.utf8), sha256: digest(Data(marker.utf8)))],
                      directories: ["Local Storage"])
    }

    func testEmptyTokenCachesAreRecognizedByLengthOnly() {
        func empty(_ object: [String: JSONValue]) -> Bool { IdentitySchema.tokenCachesKnownEmpty(.object(object)) }
        XCTAssertTrue(empty(["oauth:tokenCacheV2": cache(cipherBytes: 16)]))
        XCTAssertTrue(empty(["oauth:tokenCacheV2": .string("")]))
        XCTAssertTrue(empty(["oauth:tokenCache": cache(cipherBytes: 16), "oauth:tokenCacheV2": cache(cipherBytes: 16)]))
        XCTAssertFalse(empty(["oauth:tokenCacheV2": cache(cipherBytes: 256)]))
        XCTAssertFalse(empty(["oauth:tokenCache": cache(cipherBytes: 16), "oauth:tokenCacheV2": cache(cipherBytes: 256)]))
        XCTAssertFalse(empty(["lastKnownAccountUuid": .string(account)]))
        // Formats this check does not understand never count as empty.
        XCTAssertFalse(empty(["oauth:tokenCacheV2": .string("fixture-cache")]))
        XCTAssertFalse(empty(["oauth:tokenCacheV2": .string(Data("v11".utf8).base64EncodedString() + "AAAA")]))
        XCTAssertFalse(empty(["oauth:tokenCacheV2": cache(cipherBytes: 0)]))
        XCTAssertFalse(empty(["oauth:tokenCacheV2": cache(cipherBytes: 15)]))
    }

    func testRestoringAGenerationUndoesASaveAndItsRotation() async throws {
        let vault = vault(directory().appendingPathComponent("vault"))
        try await vault.save(snapshot("older", cache: cache(cipherBytes: 256)))
        try await vault.save(snapshot("good", cache: cache(cipherBytes: 256)))
        let before = try await vault.generation(accountID: account)
        XCTAssertNotNil(before.current); XCTAssertNotNil(before.previous)

        try await vault.save(snapshot("attempt", cache: cache(cipherBytes: 256)))
        try await vault.restore(before, accountID: account)

        let after = try await vault.generation(accountID: account)
        XCTAssertEqual(after.current, before.current)
        XCTAssertEqual(after.previous, before.previous)
        let restored = try await vault.load(accountID: account)
        XCTAssertEqual(restored.files.first?.data, Data("good".utf8))
    }

    func testRestoringAnEmptyGenerationRemovesFilesTheOperationCreated() async throws {
        let vault = vault(directory().appendingPathComponent("vault"))
        let before = try await vault.generation(accountID: account)
        XCTAssertNil(before.current); XCTAssertNil(before.previous)
        try await vault.save(snapshot("first", cache: cache(cipherBytes: 256)))
        try await vault.save(snapshot("second", cache: cache(cipherBytes: 256)))
        try await vault.restore(before, accountID: account)
        let containsAccount = await vault.contains(accountID: account)
        XCTAssertFalse(containsAccount)
        let after = try await vault.generation(accountID: account)
        XCTAssertNil(after.current); XCTAssertNil(after.previous)
    }

    func testSavingATokenlessLoginKeepsTheSavedOne() async throws {
        let home = directory(), env = MacEnvironment(home: home)
        try FileManager.default.createDirectory(at: env.desktop.appendingPathComponent("Local Storage"), withIntermediateDirectories: true)
        let config: JSONValue = .object(["lastKnownAccountUuid": .string(account), "oauth:tokenCacheV2": cache(cipherBytes: 16)])
        try JSONEncoder().encode(config).write(to: env.desktop.appendingPathComponent("config.json"))
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(env.desktop.appendingPathComponent("Cookies").path, &database), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE cookies (host_key TEXT, name TEXT, expires_utc INTEGER); INSERT INTO cookies VALUES ('.claude.ai','sessionKey',0)", nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)

        let vault = vault(env.root.appendingPathComponent("vault"))
        let engine = SwitchEngine(environment: env, vault: vault)
        let captured = try await engine.capture(version: "0.14.2")
        let withoutSaved = await engine.isTokenlessOverSaved(captured)
        XCTAssertFalse(withoutSaved, "With nothing saved there is no better login to keep")

        try await vault.save(snapshot("good", cache: cache(cipherBytes: 256)))
        let withSaved = await engine.isTokenlessOverSaved(captured)
        XCTAssertTrue(withSaved)
    }
}
