import SwiftUI
import UIKit

/// Own the native editing boundary so the final keyboard correction arrives
/// before a request starts, rather than through a later SwiftUI change event.
struct PracticeAnswerEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var editable: Bool
    /// Written on a ruled notepad: every line sits on a blue rule, with the
    /// red margin down the left, and the rules scroll with the writing.
    var ruled = false
    var onEdit: (String) -> Void
    var onCommit: (String) -> Void
    var committedOverride: () -> String? = { nil }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = RuledTextView()
        view.ruled = ruled
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        view.accessibilityIdentifier = "coach-answer"
        view.accessibilityLabel = L.t("你的回答", "Your answer")
        view.keyboardDismissMode = .interactive
        view.applyRuling()
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if let ruledView = view as? RuledTextView, ruledView.ruled != ruled {
            ruledView.ruled = ruled
            ruledView.applyRuling()
        }
        if view.text != text {
            if let ruledView = view as? RuledTextView, ruled {
                ruledView.attributedText = NSAttributedString(string: text, attributes: ruledView.typingAttributes)
            } else {
                view.text = text
            }
        }
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

/// A text view that can be a page of a ruled notepad. Every line is the same
/// height, so the rules drawn under the text stay under each line however
/// much is written, and they scroll with it.
final class RuledTextView: UITextView {
    var ruled = false
    private let rules = CAShapeLayer()
    private let margin = CAShapeLayer()

    /// Where the red margin runs and the writing starts, from the left edge.
    static let marginX: CGFloat = 30
    static let textLeft: CGFloat = 36
    static let topInset: CGFloat = 8

    static func lineHeight(for font: UIFont) -> CGFloat { (font.lineHeight + 10).rounded() }

    /// Where the first line's text starts, for a placeholder laid over it:
    /// a fixed line height adds its extra room above the letters.
    static func firstLineTop(for font: UIFont) -> CGFloat { topInset + lineHeight(for: font) - font.lineHeight }

    func applyRuling() {
        let font = self.font ?? .preferredFont(forTextStyle: .body)
        if ruled {
            textContainerInset = UIEdgeInsets(top: Self.topInset, left: Self.textLeft - textContainer.lineFragmentPadding,
                                              bottom: 8, right: 8)
            let height = Self.lineHeight(for: font)
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = height
            paragraph.maximumLineHeight = height
            var attributes = typingAttributes
            attributes[.font] = font
            attributes[.foregroundColor] = UIColor.label
            attributes[.paragraphStyle] = paragraph
            // Text set on top of the fixed line height sits on its rule.
            attributes[.baselineOffset] = 0
            typingAttributes = attributes
            if let current = text, !current.isEmpty {
                let range = selectedRange
                attributedText = NSAttributedString(string: current, attributes: attributes)
                selectedRange = range
            }
            watchTraits()
            if rules.superlayer == nil {
                rules.fillColor = nil
                rules.lineWidth = 0.8
                margin.fillColor = nil
                margin.lineWidth = 1.2
                layer.insertSublayer(rules, at: 0)
                layer.insertSublayer(margin, at: 0)
            }
        } else {
            textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
            rules.removeFromSuperlayer()
            margin.removeFromSuperlayer()
        }
        setNeedsLayout()
    }

    private var watchingTraits = false

    /// A new text size needs new line heights; a new appearance new ink.
    private func watchTraits() {
        guard !watchingTraits else { return }
        watchingTraits = true
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: RuledTextView, _: UITraitCollection) in
            if view.ruled { view.applyRuling() }
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: RuledTextView, _: UITraitCollection) in
            view.setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard ruled else { return }
        let font = self.font ?? .preferredFont(forTextStyle: .body)
        let height = Self.lineHeight(for: font)
        let bottom = max(contentSize.height, bounds.height) + height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = UIBezierPath()
        // Each line's baseline sits on its rule, the descenders just below.
        var y = Self.topInset + height + font.descender + 2
        while y <= bottom {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: max(bounds.width, contentSize.width), y: y))
            y += height
        }
        rules.path = path.cgPath
        rules.strokeColor = UIColor(Collage.ruleLine).resolvedColor(with: traitCollection).cgColor
        let line = UIBezierPath()
        line.move(to: CGPoint(x: Self.marginX, y: min(0, contentOffset.y) - 200))
        line.addLine(to: CGPoint(x: Self.marginX, y: bottom + 200))
        margin.path = line.cgPath
        margin.strokeColor = UIColor(Collage.margin).resolvedColor(with: traitCollection).cgColor
        CATransaction.commit()
    }
}
