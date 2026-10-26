import Foundation

/// The same seeded shuffle the React Native app used (FNV-1a over UTF-16
/// code units, then a 32-bit LCG whose output is scrambled), so a seed gives
/// the same order in both.
public enum SeededRandom {
    public static func hash(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for unit in text.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 16_777_619
        }
        return hash
    }

    static func next(_ state: UInt32) -> UInt32 {
        state &* 1_664_525 &+ 1_013_904_223
    }

    /// The LCG's low bits barely change, so `state % n` alone left most
    /// orderings unreachable. murmur3's finalizer mixes the high bits down.
    static func scramble(_ state: UInt32) -> UInt32 {
        var mixed = state
        mixed ^= mixed >> 16
        mixed = mixed &* 0x85EB_CA6B
        mixed ^= mixed >> 13
        mixed = mixed &* 0xC2B2_AE35
        mixed ^= mixed >> 16
        return mixed
    }

    public static func shuffle<T>(_ values: [T], seed: String) -> [T] {
        var shuffled = values
        guard shuffled.count > 1 else { return shuffled }
        var state = hash(seed.isEmpty ? "word7000" : seed)
        for index in stride(from: shuffled.count - 1, to: 0, by: -1) {
            state = next(state)
            let swapIndex = Int(scramble(state) % UInt32(index + 1))
            shuffled.swapAt(index, swapIndex)
        }
        return shuffled
    }

    /// Distinct indexes in `0..<length`, in the order they were drawn.
    public static func sampleIndexes(length: Int, count: Int, seed: String, excluding excluded: Int = -1) -> [Int] {
        guard length > 0, count > 0 else { return [] }
        let target = min(count, length - (excluded >= 0 ? 1 : 0))
        var selected: [Int] = []
        var seen = Set<Int>()
        var state = hash(seed.isEmpty ? "word7000" : seed)
        while selected.count < target {
            state = next(state)
            let index = Int(scramble(state) % UInt32(length))
            if index != excluded, seen.insert(index).inserted {
                selected.append(index)
            }
        }
        return selected
    }

    public static func runtimeSeed() -> String {
        "\(Date().timeIntervalSince1970):\(Double.random(in: 0..<1))"
    }
}
