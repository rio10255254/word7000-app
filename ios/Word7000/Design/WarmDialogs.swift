import SwiftUI

// WordCat Next: the questions the app asks ("Delete this bank?"), the lists
// of things to do ("Copy / Move / Rename…") and the one-line prompts ("Name
// the bank") as WordCat's own small sheets on warm paper, the cat beside
// them, instead of the iPhone's grey alert boxes and floating menus.
//
// What a button does runs once its sheet has gone, so an action that opens
// another sheet (or closes the page) never collides with this one.

/// One row of a `warmActions` sheet.
struct WarmAction {
    var title: String
    var icon: String
    var detail: String? = nil
    var destructive = false
    var identifier: String? = nil
    var disabled = false
    var action: () -> Void
}

extension View {
    /// Asks before doing something: the cat, the question, a confirm button
    /// (brick red when it cannot be taken back) and Cancel, in a small sheet.
    func warmConfirm(isPresented: Binding<Bool>, title: String, message: String? = nil,
                     confirmTitle: String, destructive: Bool = false, confirmIdentifier: String? = nil,
                     cancelTitle: String? = nil, mood: Mascot.Mood = .encourage,
                     action: @escaping () -> Void) -> some View {
        modifier(WarmConfirmModifier(isPresented: isPresented, title: title, message: message,
                                     confirmTitle: confirmTitle, destructive: destructive,
                                     confirmIdentifier: confirmIdentifier, cancelTitle: cancelTitle ?? L.cancel,
                                     mood: mood, action: action))
    }

    /// A short list of things to do, as big cards in a small sheet: what a
    /// menu popping up over the page was.
    func warmActions(isPresented: Binding<Bool>, title: String? = nil, actions: [WarmAction]) -> some View {
        modifier(WarmActionsModifier(isPresented: isPresented, title: title, actions: actions))
    }

    /// Asks for one line of text, e.g. a bank's name, with the keyboard up.
    func warmTextPrompt(isPresented: Binding<Bool>, title: String, text: Binding<String>, placeholder: String,
                        fieldIdentifier: String, saveTitle: String = L.save, saveIdentifier: String,
                        onSave: @escaping () -> Void) -> some View {
        modifier(WarmTextPromptModifier(isPresented: isPresented, title: title, text: text, placeholder: placeholder,
                                        fieldIdentifier: fieldIdentifier, saveTitle: saveTitle,
                                        saveIdentifier: saveIdentifier, onSave: onSave))
    }
}

// MARK: Presenting

private struct WarmConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let confirmTitle: String
    let destructive: Bool
    let confirmIdentifier: String?
    let cancelTitle: String
    let mood: Mascot.Mood
    let action: () -> Void
    /// The action to run once the sheet has gone.
    @State private var pending: (() -> Void)? = nil

    init(isPresented: Binding<Bool>, title: String, message: String?, confirmTitle: String, destructive: Bool,
         confirmIdentifier: String?, cancelTitle: String, mood: Mascot.Mood, action: @escaping () -> Void) {
        _isPresented = isPresented
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.destructive = destructive
        self.confirmIdentifier = confirmIdentifier
        self.cancelTitle = cancelTitle
        self.mood = mood
        self.action = action
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: runPending) {
            WarmConfirmSheet(title: title, message: message, confirmTitle: confirmTitle, destructive: destructive,
                             confirmIdentifier: confirmIdentifier, cancelTitle: cancelTitle, mood: mood,
                             confirm: {
                                 pending = action
                                 isPresented = false
                             },
                             cancel: { isPresented = false })
        }
    }

    private func runPending() {
        let next = pending
        pending = nil
        next?()
    }
}

private struct WarmActionsModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String?
    let actions: [WarmAction]
    @State private var pending: (() -> Void)? = nil

    init(isPresented: Binding<Bool>, title: String?, actions: [WarmAction]) {
        _isPresented = isPresented
        self.title = title
        self.actions = actions
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: runPending) {
            WarmActionSheet(title: title, actions: actions,
                            pick: { picked in
                                pending = picked.action
                                isPresented = false
                            },
                            cancel: { isPresented = false })
        }
    }

    private func runPending() {
        let next = pending
        pending = nil
        next?()
    }
}

private struct WarmTextPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    @Binding var text: String
    let placeholder: String
    let fieldIdentifier: String
    let saveTitle: String
    let saveIdentifier: String
    let onSave: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            WarmTextPromptSheet(title: title, text: $text, placeholder: placeholder,
                                fieldIdentifier: fieldIdentifier, saveTitle: saveTitle,
                                saveIdentifier: saveIdentifier,
                                save: {
                                    onSave()
                                    isPresented = false
                                },
                                cancel: { isPresented = false })
        }
    }
}

// MARK: The sheets

/// A sheet exactly as tall as what it holds, scrolling only when that is
/// more than the screen (a long list of banks).
private struct WarmSheetFrame<Content: View>: View {
    @State private var height: CGFloat = 280
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { height = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, value in height = value }
                    }
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        // As tall as the content (the system keeps it within the screen).
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Palette.background)
    }
}

private struct WarmConfirmSheet: View {
    let title: String
    let message: String?
    let confirmTitle: String
    let destructive: Bool
    let confirmIdentifier: String?
    let cancelTitle: String
    let mood: Mascot.Mood
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        WarmSheetFrame {
            VStack(spacing: 12) {
                Mascot(mood: mood, size: 64)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.display(.title3, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 10) {
                    Button(action: confirm) {
                        Text(confirmTitle).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: destructive ? Palette.miss : Palette.accent)
                    .accessibilityIdentifier(confirmIdentifier ?? "warm-confirm")
                    Button(action: cancel) {
                        Text(cancelTitle).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("warm-confirm-cancel")
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, Metrics.gutter + 4)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
    }
}

private struct WarmActionSheet: View {
    let title: String?
    let actions: [WarmAction]
    let pick: (WarmAction) -> Void
    let cancel: () -> Void

    var body: some View {
        WarmSheetFrame {
            VStack(spacing: 10) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.display(.headline, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                    row(item)
                }
                Button(action: cancel) {
                    Text(L.cancel).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .padding(.top, 4)
                .accessibilityIdentifier("warm-actions-cancel")
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 26)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func row(_ item: WarmAction) -> some View {
        let tint: Color = item.destructive ? Palette.miss : Palette.accent
        let button = Button { pick(item) } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.body.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(item.destructive ? Palette.miss : Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondaryLabel)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.khaki.opacity(0.8), lineWidth: 1)
            }
            .opacity(item.disabled ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(item.disabled)
        .accessibilityLabel(item.title)
        if let identifier = item.identifier {
            button.accessibilityIdentifier(identifier)
        } else {
            button
        }
    }
}

private struct WarmTextPromptSheet: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let fieldIdentifier: String
    let saveTitle: String
    let saveIdentifier: String
    let save: () -> Void
    let cancel: () -> Void
    @FocusState private var focused: Bool

    init(title: String, text: Binding<String>, placeholder: String, fieldIdentifier: String, saveTitle: String,
         saveIdentifier: String, save: @escaping () -> Void, cancel: @escaping () -> Void) {
        self.title = title
        _text = text
        self.placeholder = placeholder
        self.fieldIdentifier = fieldIdentifier
        self.saveTitle = saveTitle
        self.saveIdentifier = saveIdentifier
        self.save = save
        self.cancel = cancel
    }

    private var canSave: Bool { !text.trimmed.isEmpty }

    var body: some View {
        WarmSheetFrame {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Mascot(mood: .thinking, size: 46)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.display(.title3, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                TextField(placeholder, text: $text)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { if canSave { save() } }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(focused ? Palette.accent.opacity(0.7) : Palette.khaki, lineWidth: focused ? 1.5 : 1)
                    }
                    .accessibilityIdentifier(fieldIdentifier)
                ButtonRow {
                    Button(action: cancel) {
                        Text(L.cancel).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("warm-prompt-cancel")
                    Button(action: save) {
                        Text(saveTitle).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .disabled(!canSave)
                    .accessibilityIdentifier(saveIdentifier)
                }
            }
            .padding(.horizontal, Metrics.gutter + 4)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .task {
            // The keyboard comes up once the sheet has settled.
            try? await Task.sleep(for: .milliseconds(350))
            focused = true
        }
    }
}
