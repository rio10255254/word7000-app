import Foundation

/// Mandarin tones from the sound itself: the pitch of each syllable, set
/// against the learner's own voice range and compared with the shape each
/// tone should have (Taiwan Mandarin: high level, rising, low, falling).
/// It measures pitch, so it hears tones that speech recognition, which
/// guesses whole words, glosses over. It is a guide, not a grade: a
/// syllable it cannot hear clearly is left unjudged.
public enum ToneAnalysis {
    // MARK: Tones

    /// 1–4, or 5 for the neutral tone.
    public static func tone(of syllable: String) -> Int {
        for scalar in syllable.decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x0304: return 1
            case 0x0301: return 2
            case 0x030C: return 3
            case 0x0300: return 4
            default: continue
            }
        }
        return 5
    }

    /// The tones as said in a phrase: two third tones in a row make the first
    /// a second tone, and 一 and 不 change with the tone after them.
    public static func spokenTones(characters: [String], syllables: [String]) -> [Int] {
        var tones = syllables.map(tone(of:))
        guard tones.count == characters.count else { return tones }
        for index in tones.indices.dropLast() {
            let next = tones[index + 1]
            switch characters[index] {
            case "一" where next != 5:
                tones[index] = next == 4 ? 2 : 4
            case "不" where next == 4:
                tones[index] = 2
            default:
                if tones[index] == 3, next == 3 { tones[index] = 2 }
            }
        }
        return tones
    }

    /// How each tone moves on a 1 (lowest) to 5 (highest) scale, five points
    /// across the syllable. Taiwan Mandarin's third tone is mostly low.
    public static func shape(of tone: Int) -> [Double] {
        switch tone {
        case 1: [4.6, 4.6, 4.6, 4.6, 4.6]
        case 2: [3.0, 3.1, 3.6, 4.2, 4.8]
        case 3: [2.2, 1.6, 1.2, 1.2, 1.6]
        case 4: [4.8, 4.4, 3.5, 2.5, 1.6]
        default: [3, 3, 3, 3, 3]
        }
    }

    /// The tone whose shape is nearest, and by how much it beat the next
    /// nearest (0 = a toss-up).
    public static func classify(_ contour: [Double]) -> (tone: Int, margin: Double) {
        let distances = toneDistances(contour).sorted { $0.1 < $1.1 }
        return (distances[0].0, distances[1].1 - distances[0].1)
    }

    /// How far a contour is from each tone's shape (1–4).
    static func toneDistances(_ contour: [Double]) -> [(Int, Double)] {
        let points = resample(contour, to: 5)
        // Height and movement both count: a falling tone and a high level one
        // start alike, and only the movement tells them apart.
        func steps(_ values: [Double]) -> [Double] { zip(values.dropFirst(), values).map { $0 - $1 } }
        func rms(_ a: [Double], _ b: [Double]) -> Double {
            let sum = zip(a, b).reduce(0.0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
            return (sum / Double(max(a.count, 1))).squareRoot()
        }
        return (1...4).map { tone -> (Int, Double) in
            let template = shape(of: tone)
            let level = rms(points, template)
            let movement = rms(steps(points), steps(template))
            return (tone, level + 2 * movement)
        }
    }

    /// The tone heard for a syllable that should have `expected`: that tone,
    /// unless another fits the pitch clearly better (by `slipMargin`). Judged
    /// against the tone it should be rather than between the two nearest, so a
    /// wrong tone is caught even when two other tones fit about as well.
    public static func judge(_ contour: [Double], expected: Int) -> Int? {
        let distances = toneDistances(contour)
        guard let best = distances.min(by: { $0.1 < $1.1 }) else { return nil }
        guard let fit = distances.first(where: { $0.0 == expected })?.1 else {
            // The neutral tone is never judged; say what it sounded like only when clear.
            let (tone, margin) = classify(contour)
            return margin >= clearMargin ? tone : nil
        }
        return fit - best.1 >= slipMargin ? best.0 : expected
    }

    /// A syllable written with another tone: "ma" + 3 → "mǎ".
    public static func syllable(_ syllable: String, withTone tone: Int) -> String {
        let base = ChineseDisplay.stripTones(syllable)
        guard (1...4).contains(tone) else { return base }
        let mark: Character = ["\u{0304}", "\u{0301}", "\u{030C}", "\u{0300}"][tone - 1]
        let letters = Array(base)
        // a or e take the mark; in "ou" the o; otherwise the last vowel.
        let vowels = "aeiouü"
        let target = letters.firstIndex(where: { $0 == "a" || $0 == "e" })
            ?? (base.contains("ou") ? letters.firstIndex(of: "o") : nil)
            ?? letters.lastIndex(where: { vowels.contains($0) })
        guard let target else { return base }
        var result = ""
        for (index, letter) in letters.enumerated() {
            result.append(letter)
            if index == target { result.append(mark) }
        }
        return result.precomposedStringWithCanonicalMapping
    }

    /// Where each of `characters` was said, from the recognizer's timed
    /// pieces of text (a piece's time is shared out over its characters).
    /// Characters not found in what was heard get nil.
    public static func spans(of characters: [String], in pieces: [(text: String, start: Double, duration: Double)]) -> [ClosedRange<Double>?] {
        var timeline: [(character: String, span: ClosedRange<Double>)] = []
        for piece in pieces {
            let han = piece.text.filter(ChineseDisplay.isHan).map(String.init)
            guard !han.isEmpty, piece.duration > 0 else { continue }
            let step = piece.duration / Double(han.count)
            for (index, character) in han.enumerated() {
                let from = piece.start + step * Double(index)
                timeline.append((character, from...(from + step)))
            }
        }
        var next = 0
        return characters.map { character in
            let sound = ChineseDisplay.stripTones(ShadowingCheck.characterPinyin(character))
            let window = timeline.indices.dropFirst(next).prefix(4)
            guard let found = window.first(where: { index in
                timeline[index].character == character
                    || (!sound.isEmpty && ChineseDisplay.stripTones(ShadowingCheck.characterPinyin(timeline[index].character)) == sound)
            }) else { return nil }
            next = found + 1
            return timeline[found].span
        }
    }

    public static func toneName(_ tone: Int) -> String {
        switch tone {
        case 1: "一聲"
        case 2: "二聲"
        case 3: "三聲"
        case 4: "四聲"
        default: "輕聲"
        }
    }

    // MARK: Syllables

    /// What was measured for one syllable.
    public struct Syllable: Equatable, Sendable {
        /// The expected tone as said in the phrase (1–5).
        public let expected: Int
        /// The tone heard, when it could be heard clearly.
        public let heard: Int?
        /// The pitch across the syllable on the 1–5 scale, for drawing.
        public let contour: [Double]

        public init(expected: Int, heard: Int?, contour: [Double]) {
            self.expected = expected
            self.heard = heard
            self.contour = contour
        }

        /// Heard with another tone (a neutral tone is never judged).
        public var mismatched: Bool { expected != 5 && heard != nil && heard != expected }
    }

    /// How far ahead the nearest tone must be to count as heard.
    public static let clearMargin = 0.45
    /// How much better another tone must fit than the one asked for to count
    /// as a slip.
    public static let slipMargin = 0.3

    /// Measures each syllable of a take. `spans` are where each syllable
    /// falls, in seconds (nil where it is not known); `expected` the tones
    /// to say. Returns one entry per syllable, nil where nothing was heard.
    public static func analyze(samples: [Float], rate: Double, spans: [ClosedRange<Double>?], expected: [Int]) -> [Syllable?] {
        let track = PitchTracker.track(samples: samples, rate: rate)
        let voiced = track.compactMap(\.hz)
        guard voiced.count >= 5 else { return spans.map { _ in nil } }
        // The learner's own range, so high and low voices compare alike.
        let semitones = voiced.map(semitone).sorted()
        let low = semitones[Int(Double(semitones.count - 1) * 0.08)]
        let high = semitones[Int(Double(semitones.count - 1) * 0.92)]
        let range = max(high - low, 4)
        func scale(_ hz: Double) -> Double { 1 + 4 * min(max((semitone(hz) - low) / range, 0), 1) }

        return zip(spans, expected).map { span, tone in
            guard let span else { return nil }
            let frames = track.filter { span.contains($0.time) }.compactMap(\.hz)
            guard frames.count >= 4 else { return nil }
            // The ends of a syllable are its least steady part.
            let trim = frames.count >= 8 ? frames.count / 8 : 0
            let contour = Array(frames.dropFirst(trim).dropLast(trim)).map(scale)
            return Syllable(expected: tone, heard: judge(contour, expected: tone), contour: resample(contour, to: 12))
        }
    }

    /// Where each of `count` syllables falls when only the voiced stretch of
    /// the take is known: shared out evenly.
    public static func evenSpans(samples: [Float], rate: Double, count: Int) -> [ClosedRange<Double>?] {
        let track = PitchTracker.track(samples: samples, rate: rate)
        guard count > 0, let first = track.first(where: { $0.hz != nil })?.time,
              let last = track.last(where: { $0.hz != nil })?.time, last > first else {
            return Array(repeating: nil, count: count)
        }
        let step = (last - first) / Double(count)
        return (0..<count).map { index -> ClosedRange<Double>? in
            let from: Double = first + step * Double(index)
            let to: Double = from + step
            return from...to
        }
    }

    static func semitone(_ hz: Double) -> Double { 12 * log2(hz / 55) }

    static func resample(_ values: [Double], to count: Int) -> [Double] {
        guard values.count > 1 else { return Array(repeating: values.first ?? 3, count: count) }
        return (0..<count).map { index in
            let position = Double(index) * Double(values.count - 1) / Double(count - 1)
            let lower = Int(position), upper = min(lower + 1, values.count - 1)
            let weight = position - Double(lower)
            return values[lower] * (1 - weight) + values[upper] * weight
        }
    }
}

/// The pitch of a voice over time (YIN), every 10 ms.
public enum PitchTracker {
    public struct Frame: Equatable, Sendable {
        public let time: Double
        /// Nil where the sound is not voiced.
        public let hz: Double?
    }

    static let workingRate = 16_000.0
    static let minimumHz = 70.0
    static let maximumHz = 450.0

    public static func track(samples: [Float], rate: Double) -> [Frame] {
        guard rate > 0, !samples.isEmpty else { return [] }
        let signal = downsample(samples, from: rate)
        let window = Int(workingRate * 0.032)
        let hop = Int(workingRate * 0.010)
        let minLag = Int(workingRate / maximumHz), maxLag = Int(workingRate / minimumHz)
        guard signal.count >= window + maxLag else { return [] }
        // Quieter than this is silence.
        let loudest = signal.reduce(Float(0)) { max($0, abs($1)) }
        let floor = Double(loudest) * 0.06

        var frames: [Frame] = []
        var difference = [Double](repeating: 0, count: maxLag + 1)
        var start = 0
        while start + window + maxLag <= signal.count {
            let time = (Double(start) + Double(window) / 2) / workingRate
            var energy = 0.0
            for index in start..<(start + window) { energy += Double(signal[index] * signal[index]) }
            guard (energy / Double(window)).squareRoot() > floor else {
                frames.append(Frame(time: time, hz: nil)); start += hop; continue
            }
            for lag in 1...maxLag {
                var sum = 0.0
                for index in start..<(start + window) {
                    let delta = Double(signal[index] - signal[index + lag])
                    sum += delta * delta
                }
                difference[lag] = sum
            }
            // Cumulative mean normalized difference; the first dip under the
            // threshold is the period.
            var running = 0.0
            var normalized = [Double](repeating: 1, count: maxLag + 1)
            for lag in 1...maxLag {
                running += difference[lag]
                normalized[lag] = running > 0 ? difference[lag] * Double(lag) / running : 1
            }
            var chosen: Int?
            var lag = minLag
            while lag <= maxLag {
                if normalized[lag] < 0.2 {
                    while lag + 1 <= maxLag, normalized[lag + 1] < normalized[lag] { lag += 1 }
                    chosen = lag
                    break
                }
                lag += 1
            }
            if let period = chosen {
                // Parabolic interpolation around the dip.
                var refined = Double(period)
                if period > minLag, period < maxLag {
                    let a = normalized[period - 1], b = normalized[period], c = normalized[period + 1]
                    let denominator = a - 2 * b + c
                    if denominator != 0 { refined += 0.5 * (a - c) / denominator }
                }
                frames.append(Frame(time: time, hz: workingRate / refined))
            } else {
                frames.append(Frame(time: time, hz: nil))
            }
            start += hop
        }
        return smooth(frames)
    }

    /// Averages to the working rate.
    static func downsample(_ samples: [Float], from rate: Double) -> [Float] {
        guard rate > workingRate * 1.01 else { return samples }
        let ratio = rate / workingRate
        let count = Int(Double(samples.count) / ratio)
        return (0..<count).map { index in
            let from = Int(Double(index) * ratio), to = min(samples.count, max(from + 1, Int(Double(index + 1) * ratio)))
            var sum: Float = 0
            for position in from..<to { sum += samples[position] }
            return sum / Float(to - from)
        }
    }

    /// Drops single-frame octave jumps and lone voiced frames.
    static func smooth(_ frames: [Frame]) -> [Frame] {
        frames.indices.map { index in
            guard let hz = frames[index].hz else { return frames[index] }
            let neighbours = [index - 2, index - 1, index + 1, index + 2]
                .filter { frames.indices.contains($0) }
                .compactMap { frames[$0].hz }
            guard neighbours.count >= 2 else { return Frame(time: frames[index].time, hz: nil) }
            let median = neighbours.sorted()[neighbours.count / 2]
            if hz > median * 1.7 || hz < median / 1.7 { return Frame(time: frames[index].time, hz: median) }
            return frames[index]
        }
    }
}
