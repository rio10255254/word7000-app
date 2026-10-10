import SwiftUI
import Word7000Core

enum AppTab: Hashable {
    case home, study, quiz, library, profile
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .home
    @State private var bankPickerOpen = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(selectTab: { tab = $0 }, openBankPicker: { bankPickerOpen = true })
            }
            .tabItem { Label(L.tabHome, systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                StudyView(selectTab: { tab = $0 }, openBankPicker: { bankPickerOpen = true })
            }
            .tabItem { Label(L.tabStudy, systemImage: "rectangle.on.rectangle.angled") }
            .tag(AppTab.study)

            NavigationStack {
                QuizView(selectTab: { tab = $0 }, openBankPicker: { bankPickerOpen = true })
            }
            .tabItem { Label(L.tabQuiz, systemImage: "checklist") }
            .tag(AppTab.quiz)

            NavigationStack {
                LibraryView(openBankPicker: { bankPickerOpen = true })
            }
            .tabItem { Label(L.tabLibrary, systemImage: "books.vertical.fill") }
            .tag(AppTab.library)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label(L.tabProfile, systemImage: "person.crop.circle.fill") }
            .tag(AppTab.profile)
        }
        .sheet(isPresented: $bankPickerOpen) {
            BankPickerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// The word bank this screen works on, with a way to switch it.
struct BankButton: View {
    @Environment(AppModel.self) private var model
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: model.bankIsScan ? "doc.text.viewfinder" : "square.stack.3d.up.fill")
                    .font(.subheadline.weight(.semibold))
                Text(model.bankName)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(L.bankLabel) \(model.bankName)")
        .accessibilityHint(L.bankPickerHint)
        .accessibilityIdentifier("bank-button")
    }
}
