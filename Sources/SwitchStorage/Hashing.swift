import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Incremental SHA-256 as lowercase hex. Apple platforms use CryptoKit; others use `PortableSHA256`.
public struct SHA256Hex {
    #if canImport(CryptoKit)
    private var state = SHA256()
    #else
    private var state = PortableSHA256()
    #endif
    public init() {}
    public mutating func update(_ data: Data) { state.update(data: data) }
    public func finalize() -> String { state.finalize().map { String(format: "%02x", $0) }.joined() }
}

/// FIPS 180-4 SHA-256 for platforms without CryptoKit. Used for file fingerprints, never for keys.
struct PortableSHA256 {
    private static let constants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]
    private var state: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    private var pending: [UInt8] = []
    private var length: UInt64 = 0

    mutating func update(data: Data) {
        length &+= UInt64(data.count)
        pending.append(contentsOf: data)
        var offset = 0
        while pending.count - offset >= 64 { compress(pending[offset..<offset + 64]); offset += 64 }
        pending.removeFirst(offset)
    }

    func finalize() -> [UInt8] {
        var result = self
        var tail = pending + [0x80]
        while tail.count % 64 != 56 { tail.append(0) }
        let bits = length &* 8
        for shift in stride(from: 56, through: 0, by: -8) { tail.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift))) }
        for offset in stride(from: 0, to: tail.count, by: 64) { result.compress(tail[offset..<offset + 64]) }
        return result.state.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> UInt32(24 - 8 * $0)) } }
    }

    private mutating func compress(_ block: ArraySlice<UInt8>) {
        func rotate(_ value: UInt32, _ count: UInt32) -> UInt32 { value >> count | value << (32 - count) }
        var w = [UInt32](repeating: 0, count: 64)
        for index in 0..<16 {
            let at = block.startIndex + index * 4
            w[index] = UInt32(block[at]) << 24 | UInt32(block[at + 1]) << 16 | UInt32(block[at + 2]) << 8 | UInt32(block[at + 3])
        }
        for index in 16..<64 {
            let s0 = rotate(w[index - 15], 7) ^ rotate(w[index - 15], 18) ^ (w[index - 15] >> 3)
            let s1 = rotate(w[index - 2], 17) ^ rotate(w[index - 2], 19) ^ (w[index - 2] >> 10)
            w[index] = w[index - 16] &+ s0 &+ w[index - 7] &+ s1
        }
        var a = state[0], b = state[1], c = state[2], d = state[3], e = state[4], f = state[5], g = state[6], h = state[7]
        for index in 0..<64 {
            let s1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25)
            let t1 = h &+ s1 &+ ((e & f) ^ (~e & g)) &+ Self.constants[index] &+ w[index]
            let s0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22)
            let t2 = s0 &+ ((a & b) ^ (a & c) ^ (b & c))
            h = g; g = f; f = e; e = d &+ t1; d = c; c = b; b = a; a = t1 &+ t2
        }
        for (index, value) in [a, b, c, d, e, f, g, h].enumerated() { state[index] &+= value }
    }
}
