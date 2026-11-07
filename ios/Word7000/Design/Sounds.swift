import AudioToolbox
import SwiftUI

/// WordCat Next: short sounds for answers and celebrations, made by
/// `scripts/make-sound-effects.mjs`.
enum SoundEffect: String, CaseIterable {
    case correct, wrong, star1, star2, star3, stamp, complete

    /// The star landing `number`-th (1 to 3), each a note higher.
    static func star(_ number: Int) -> SoundEffect {
        number <= 1 ? .star1 : number == 2 ? .star2 : .star3
    }
}

/// Plays them as system sounds: silent when the phone is set to silent, as
/// loud as the ringer, and apart from the audio session that speaking
/// records and reads aloud with, so they never cut into it.
@MainActor
enum SoundBoard {
    private static var ids: [SoundEffect: SystemSoundID] = [:]

    static func play(_ effect: SoundEffect) {
        if ids[effect] == nil {
            let name = "sfx-\(effect.rawValue)"
            // Copied to the bundle's top level, or kept in its folder.
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
                    ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") else { return }
            var id: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { return }
            ids[effect] = id
        }
        if let id = ids[effect] { AudioServicesPlaySystemSound(id) }
    }
}

extension AppModel {
    /// Sound effects are on unless turned off in Settings.
    var soundEffectsOn: Bool { settings.soundEffectsEnabled ?? true }

    func playSound(_ effect: SoundEffect) {
        guard soundEffectsOn else { return }
        SoundBoard.play(effect)
    }
}

extension View {
    /// Plays the sound `effect` picks each time `trigger` changes (nil: none),
    /// the way `sensoryFeedback(trigger:_:)` gives a tap.
    func soundEffect<T: Equatable>(trigger: T, _ effect: @escaping (_ old: T, _ new: T) -> SoundEffect?) -> some View {
        modifier(SoundEffectOnChange(trigger: trigger, effect: effect))
    }
}

private struct SoundEffectOnChange<T: Equatable>: ViewModifier {
    @Environment(AppModel.self) private var model
    var trigger: T
    var effect: (T, T) -> SoundEffect?

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { old, new in
            if let sound = effect(old, new) { model.playSound(sound) }
        }
    }
}
