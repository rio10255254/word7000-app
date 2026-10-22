import SwiftUI
import AVFoundation
import Speech

struct IntelligenceSettingsView: View {
    @Environment(\.scenePhase) private var phase
    @State private var speech = SpeakingRecorder()
    @State private var permissionsRevision = 0
    private var settings: IntelligenceSettings { .shared }

    var body: some View {
        Form {
            Section {
                Toggle(L.t("裝置內 AI 建議", "On-device AI suggestions"), isOn: Binding(
                    get: { settings.enabled }, set: { settings.enabled = $0; AppleSpeakingCoach.shared.refreshAvailability() }))
                    .accessibilityIdentifier("settings-ai-toggle")
                LabeledContent(L.t("口說教練", "Speaking coach"), value: coachStatus)
                    .accessibilityIdentifier("settings-ai-status")
                LabeledContent(L.t("掃描整理", "Scan assistance"), value: SmartScan.canOrganize ? L.t("可使用", "Available") : L.t("未啟用", "Unavailable"))
                LabeledContent(L.t("雲端 AI", "Cloud AI"), value: L.t("未接入", "Not connected"))
            } footer: {
                Text(L.t("關閉 AI 不影響原本的單字、測驗、錄音與口說練習。", "Turning AI off does not change your words, quizzes, recordings or regular speaking practice."))
            }
            Section {
                LabeledContent(L.t("麥克風", "Microphone"), value: microphoneStatus)
                LabeledContent(L.t("離線語音辨識", "Offline transcription"), value: speechStatus)
                Button { Task { await refresh() } } label: {
                    Label(L.t("重新檢查", "Check again"), systemImage: "arrow.clockwise")
                }
                Button(L.t("開啟系統設定", "Open System Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Section {
                Text(L.t("錄音、口說回答和 AI 建議不會上傳，也不會存入帳號。錄音離開練習頁即刪除；回答在離開這題後清除。", "Recordings, speaking answers and AI suggestions are not uploaded or saved to your account. Recordings are deleted when you leave the practice sheet; answers are cleared when you leave the question."))
                Text(L.t("目前不收集 AI 使用比例或滿意度。App 只會讀取功能開關，不附帶帳號、錄音或回答。", "AI usage and satisfaction are not collected. The app only fetches feature availability settings, without account details, recordings or answers."))
                Text(L.t("登入與學習同步仍依原本的隱私權政策處理。", "Sign-in and learning sync still follow the existing privacy policy."))
            } header: { Text(L.t("隱私", "Privacy")) }
        }
        .navigationTitle(L.t("AI 與錄音", "AI and recording"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .onChange(of: phase) { _, value in if value == .active { Task { await refresh() } } }
    }

    private func refresh() async {
        permissionsRevision += 1
        AppleSpeakingCoach.shared.refreshAvailability()
        await speech.refresh(language: L.zh ? "en-US" : "zh-TW")
    }
    private var microphoneStatus: String {
        _ = permissionsRevision
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return L.t("已允許", "Allowed")
        case .denied: return L.t("未允許", "Not allowed")
        default: return L.t("尚未要求", "Not requested")
        }
    }
    private var speechStatus: String {
        switch speech.support {
        case .checking: L.t("檢查中", "Checking")
        case .modern: L.t("此語言可使用", "Available for this language")
        case .legacy:
            SFSpeechRecognizer.authorizationStatus() == .denied || SFSpeechRecognizer.authorizationStatus() == .restricted
                ? L.t("尚未允許辨識", "Recognition not allowed")
                : L.t("此語言可使用", "Available for this language")
        case .download: L.t("需先下載語言", "Language download needed")
        case .unavailable: L.t("此裝置或語言未支援", "Device or language unsupported")
        }
    }
    private var coachStatus: String {
        switch AppleSpeakingCoach.shared.availability {
        case .ready: L.t("可使用", "Available")
        case .unsupported: L.t("此手機不支援", "Unsupported iPhone")
        case .disabled: L.t("請開啟 Apple Intelligence", "Enable Apple Intelligence")
        case .preparing: L.t("系統模型準備中", "Model preparing")
        case .unsupportedLanguage: L.t("語言未支援", "Language unsupported")
        case .paused: L.t("目前已關閉", "Currently off")
        case .unavailable: L.t("暫時無法使用", "Temporarily unavailable")
        }
    }
}
