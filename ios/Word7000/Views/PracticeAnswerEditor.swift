import SwiftUI
import UIKit

/// Own the native editing boundary so the final keyboard correction arrives
/// before a request starts, rather than through a later SwiftUI change event.
struct PracticeAnswerEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var editable: Bool
    var onEdit: (String) -> Void
    var onCommit: (String) -> Void
    var committedOverride: () -> String? = { nil }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        view.accessibilityIdentifier = "coach-answer"
        view.accessibilityLabel = L.t("你的回答", "Your answer")
        view.keyboardDismissMode = .interactive
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
        view.isEditable = editable
        view.accessibilityLabel = L.t("你的回答", "Your answer")
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PracticeAnswerEditor
        init(_ parent: PracticeAnswerEditor) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) { parent.focused = true }
        func textViewDidChange(_ textView: UITextView) {
            let value = textView.text ?? ""
            parent.text = value
            parent.onEdit(value)
        }
        func textViewDidEndEditing(_ textView: UITextView) {
            let value = parent.committedOverride() ?? textView.text ?? ""
            if textView.text != value { textView.text = value }
            parent.text = value
            parent.focused = false
            parent.onCommit(value)
        }
    }
}
