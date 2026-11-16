import Foundation
import XCTest
@testable import SwitchStorage

final class HashingTests: XCTestCase {
    private func portable(_ data: Data, pieces: Int = 1) -> String {
        var hash = PortableSHA256()
        let size = max(1, data.count / pieces)
        var offset = 0
        while offset < data.count {
            hash.update(data: data.subdata(in: offset..<min(data.count, offset + size))); offset += size
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private func system(_ data: Data) -> String {
        var hash = SHA256Hex(); hash.update(data); return hash.finalize()
    }

    func testKnownAnswers() {
        XCTAssertEqual(portable(Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(portable(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(system(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testPortableMatchesSystemAcrossBlockBoundaries() {
        for count in [1, 55, 56, 57, 63, 64, 65, 119, 120, 128, 4096, 10_001] {
            let data = Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
            XCTAssertEqual(portable(data), system(data), "length \(count)")
            XCTAssertEqual(portable(data, pieces: 7), system(data), "length \(count) in pieces")
        }
    }
}
