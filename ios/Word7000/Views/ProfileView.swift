import SwiftUI
import Word7000Core

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        let stats = model.stats
        let percent = Int((model.dailyFraction * 100).rounded())

        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Palette.accent)
                    Text(L.profileIdle).font(.rounded(.title3, weight: .bold))
                    Text(L.profileProgress(percent: percent, mastered: stats.mastered))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 0) {
                        StatTile(value: model.progress.streak, label: L.streak, color: Palette.review)
                        Divider().frame(height: 36)
                        StatTile(value: stats.mastered, label: L.mastered, color: Palette.known)
                        Divider().frame(height: 36)
                        StatTile(value: stats.favorites, label: L.favoriteWords)
                        Divider().frame(height: 36)
                        StatTile(value: max(0, stats.remaining), label: L.remainingWords)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Picker(L.dailyTargetTitle, selection: Binding(
                    get: { model.progress.dailyTarget },
                    set: { model.setDailyTarget($0) }
                )) {
                    ForEach(dailyTargetOptions, id: \.self) { value in
                        Text(L.dailyTargetOption(value)).tag(value)
                    }
                }
            } header: {
                Text(L.settings)
            } footer: {
                Text(L.dailyTargetText)
            }

            Section {
                Picker(L.appearance, selection: Binding(
                    get: { model.settings.theme },
                    set: { model.settings.theme = $0 }
                )) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L.appearance)
            }

            Section(L.account) {
                Label(L.accountComing, systemImage: "icloud")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!) {
                    Label(L.privacyPolicy, systemImage: "hand.raised.fill")
                }
                Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/support.html")!) {
                    Label(L.supportPage, systemImage: "questionmark.circle.fill")
                }
                LabeledContent(L.version, value: Bundle.main.versionLabel)
            }
        }
        .navigationTitle(L.tabProfile)
    }
}

extension Bundle {
    var versionLabel: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
