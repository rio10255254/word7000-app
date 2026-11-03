import UIKit

extension Notification.Name {
    /// The iPhone was shaken (the system's shake gesture).
    static let deviceDidShake = Notification.Name("word7000.deviceDidShake")
}

extension UIWindow {
    /// Passes the system's shake gesture on as a notification, so the
    /// companion can complain about being shaken.
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
