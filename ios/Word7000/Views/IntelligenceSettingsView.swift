import SwiftUI
import AVFoundation
import Speech

struct IntelligenceSettingsView: View {
    @Environment(\.scenePhase) private var phase
    @State private var speech = SpeakingRecorder()
    @State private var permissionsRevision = 0
    @State private var askCloud = false
    private var settings: IntelligenceSettings { .shared }

    var body: some View {
        Form {
            Section {
                Toggle(L.t("AI 建議", "AI suggestions"), isOn: Binding(
                    get: { settings.enabled }, set: { settings.enabled = $0; AppleSpeakingCoach.shared.refreshAvailability() }))
                    .accessibilityIdentifier("settings-ai-toggle")
                Toggle(L.t("線上 AI（Groq）", "Online AI (Groq)"), isOn: Binding(
                    get: { settings.cloudEnabled && settings.cloudConsent != false },
                    set: { on in
                        if on, settings.cloudConsent != true { settings.cloudEnabled = true; askCloud = true }
                        else { settings.cloudEnabled = on }
                        AppleSpeakingCoach.shared.refreshAvailability()
                    }))
                    .disabled(!settings.enabled)
                    .accessibilityIdentifier("settings-cloud-ai-toggle")
                LabeledContent(L.t("線上 AI", "Online AI"), value: CloudAssistant.shared.statusText)
                    .accessibilityIdentifier("settings-cloud-ai-status")
                LabeledContent(L.t("口說教練", "Speaking coach"), value: coachStatus)
                    .accessibilityIdentifier("settings-ai-status")
                LabeledContent(L.t("掃描整理", "Scan assistance"), value: SmartScan.canOrganize ? L.t("可使用", "Available") : L.t("未啟用", "Unavailable"))
            } footer: {
                Text(L.t("線上 AI 由 Groq 的最強與次強模型（GPT-OSS 120B、20B）回答，忙碌時自動分流到另一個模型，再不行就改用裝置內 AI。關閉 AI 不影響原本的單字、測驗、錄音與口說練習。",
                         "Online AI answers with Groq's strongest and second-strongest models (GPT-OSS 120B and 20B), switching to the other model when one is busy and to on-device AI after that. Turning AI off does not change your words, quizzes, recordings or regular speaking practice."))
            }
            Section {
                LabeledContent(L.t("麥克風", "Microphone"), value: microphoneStatus)
                LabeledContent(L.t("離線語音辨識", "Offline transcription"), value: speechStatus)
                Button { Task { await settings.refreshPolicy(force: true); await refresh() } } label: {
                    Label(L.t("重新檢查", "Check again"), systemImage: "arrow.clockwise")
                }
                .disabled(settings.checking)
                if settings.checking { ProgressView() }
                Button(L.t("開啟系統設定", "Open System Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Section {
                Text(L.t("錄音不會上傳，離開練習頁即刪除。口說回答和 AI 建議不會存入帳號，回答在離開這題後清除。", "Recordings are never uploaded and are deleted when you leave the practice sheet. Speaking answers and AI suggestions are not saved to your account; answers are cleared when you leave the question."))
                Text(L.t("使用線上 AI 時，你的文字回答、掃描到的文字或查詢的單字會傳送到 Groq（美國）產生建議，不包含錄音、帳號名稱或 Email。只用裝置內 AI 時，這些內容都留在 iPhone 上。", "With online AI, your typed or spoken answer text, scanned text or the word you ask about is sent to Groq (USA) to produce suggestions, without recordings, your account name or email. With on-device AI only, all of it stays on this iPhone."))
                Text(L.t("為了公平分配線上 AI，伺服器只記錄每個帳號每天的使用次數，不記錄內容。", "To share online AI fairly, the server counts requests per account per day, without their content."))
                Text(L.t("登入與學習同步仍依原本的隱私權政策處理。", "Sign-in and learning sync still follow the existing privacy policy."))
            } header: { Text(L.t("隱私", "Privacy")) }
        }
        .cloudConsentAlert(isPresented: $askCloud) { AppleSpeakingCoach.shared.refreshAvailability() }
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
