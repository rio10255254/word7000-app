import SwiftUI
import UIKit
import VisionKit
import Word7000Core

/// Photograph (or paste) a vocabulary sheet, check what was read, and save it
/// as a word bank. The meaning saved is the one printed on the paper.
struct ScanView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.dismiss) private var dismiss
    var onStudy: () -> Void

    enum Phase: Equatable {
        case choose
        case loadingPhoto
        case reading
        case review
        case saved(count: Int, name: String)
    }

    struct Row: Identifiable, Equatable {
        let id: String
        var include = true
        var word: String
        var partOfSpeech: String
        var meaning: String
        /// What was read before it was matched to a dictionary word.
        var originalWord: String?
        var suggestedWord: String?
        var needsReview = false
    }

    enum Target: Hashable {
        case new
        case existing(String)
    }

    @State private var phase: Phase = .choose
    @State private var rows: [Row] = []
    @State private var pasted = (ProcessInfo.processInfo.arguments.contains("-uiTestingReset")
        || ProcessInfo.processInfo.arguments.contains("-uiTestingScanText"))
        ? ProcessInfo.processInfo.environment["WORD7000_SCAN_TEST_TEXT"] ?? "" : ""
    @State private var photoLibraryOpen = false
    @State private var pendingPhotos: [NSItemProvider] = []
    @State private var scanTask: Task<Void, Never>?
    @State private var cameraOpen = false
    @State private var documentScannerOpen = false
    @State private var suggester: WordSuggester?
    @State private var message: String?
    @State private var sourcePreviews: [UIImage] = []
    @State private var previewOpen = false
    @State private var pageCount = 0
    @State private var target: Target = .new
    /// The paywall, shown over the scanner when the allowance runs out here.
    @State private var paywall: PaywallReason?
    @State private var askCloud = false
    @State private var afterCloudAnswer: (() -> Void)?
    @State private var newBankName = WordBanks.defaultScanBankName(chineseMode: L.mode == .chinese)

    private var destinationBanks: [CustomVocabSet] { model.customSets.sets }

    private var selectedRows: [Row] { rows.filter(\.include) }

    private var importPlan: ScanImportPlan {
        let existing: [WordEntry]
        if case let .existing(id) = target, let set = model.customSets.sets.first(where: { $0.id == id }) {
            existing = WordBanks.words(of: set, in: model.allWords)
        } else { existing = [] }
        return ScanImportPlan(rows: selectedRows.map {
            ReviewedScanWord(meaningZh: $0.meaning, partOfSpeech: $0.partOfSpeech, word: $0.word)
        }, existing: existing)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .choose: chooser
                case .loadingPhoto:
                    ProgressView(S.loadingPhoto)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("scan-loading-photo")
                case .reading:
                    ProgressView(SmartScan.canOrganize ? S.readingSmart : S.reading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review: review
                case let .saved(count, name): saved(count: count, name: name)
                }
            }
            .background(Palette.background)
            .navigationTitle(S.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.closeSheet) { dismiss() }
                        .accessibilityIdentifier("scan-close")
                }
                if phase == .review {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(S.rescan) { phase = .choose; rows = [] }
                    }
                }
            }
        }
        .sheet(isPresented: $photoLibraryOpen, onDismiss: loadSelectedPhoto) {
            PhotoLibraryPicker { providers in
                pendingPhotos = providers
                photoLibraryOpen = false
            }
            .ignoresSafeArea()
        }
        .sheet(item: $paywall) { reason in PaywallView(reason: reason) }
        .cloudConsentAlert(isPresented: $askCloud) {
            let action = afterCloudAnswer
            afterCloudAnswer = nil
            action?()
        }
        .sheet(isPresented: $previewOpen) {
            NavigationStack {
                TabView {
                    ForEach(sourcePreviews.indices, id: \.self) { index in
                        ScanSourcePreview(image: sourcePreviews[index]).tag(index)
                    }
                }
                .tabViewStyle(.page)
                .background(Color.black)
                .navigationTitle(L.t("原始頁面", "Source pages"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.closeSheet) { previewOpen = false } } }
            }
        }
        .fullScreenCover(isPresented: $cameraOpen) {
            CameraPicker { image in startReading([image]) }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $documentScannerOpen) {
            DocumentScanner { scan in
                scanTask?.cancel()
                scanTask = Task { await readPages(count: scan.pageCount) { scan.imageOfPage(at: $0) } }
            }
                .ignoresSafeArea()
        }
        .onDisappear { scanTask?.cancel() }
        .onChange(of: model.customSets.sets.map(\.id)) { _, ids in
            if case let .existing(id) = target, !ids.contains(id) { target = .new }
        }
    }

    // MARK: Choose a source

    private var chooser: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 64, height: 64)
                        .background(Palette.accent.opacity(0.14), in: Circle())
                    Text(S.intro)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if case .trial = plus.access {
                        Label(P.scansLeft(plus.policy.trialScansLeft), systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(plus.policy.trialScansLeft <= 1 ? Palette.review : Palette.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background((plus.policy.trialScansLeft <= 1 ? Palette.review : Palette.accent).opacity(0.12), in: Capsule())
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                if DocumentScanner.isAvailable {
                    Button { allowScan { documentScannerOpen = true } } label: {
                        Label(S.scanDocument, systemImage: "doc.viewfinder.fill")
                    }
                    .accessibilityIdentifier("scan-document")
                } else if CameraPicker.isAvailable {
                    Button { allowScan { cameraOpen = true } } label: {
                        Label(S.takePhoto, systemImage: "camera.fill")
                    }
                }
                Button { allowScan { photoLibraryOpen = true } } label: {
                    Label(S.choosePhoto, systemImage: "photo.on.rectangle")
                }
                .accessibilityIdentifier("scan-choose-photo")
                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.review)
                        .accessibilityIdentifier("scan-message")
                }
            }

            Section {
                TextField(S.pastePlaceholder, text: $pasted, axis: .vertical)
                    .lineLimit(4...10)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("scan-pasted-text")
                Button(S.readPasted) {
                    sourcePreviews = []
                    pageCount = 0
                    let found = ScanParser.parse(ScanParser.lines(fromPlainText: pasted))
                    showReview(found)
                }
                .accessibilityIdentifier("scan-read-pasted")
                .disabled(pasted.trimmed.isEmpty)
            } header: {
                Text(S.pasteTitle)
            } footer: {
                Text(S.pasteHint)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Every read counts against the trial allowance, so check before each one.
    private func allowScan(_ action: @escaping () -> Void) {
        switch plus.decide(.scan) {
        case .allowed:
            // Ask about the online AI before the camera opens, not halfway through reading.
            if IntelligenceSettings.shared.scanAllowed, CloudAssistant.shared.needsConsent {
                afterCloudAnswer = action
                askCloud = true
            } else {
                action()
            }
        case .needsPlus: paywall = .locked(.scan)
        case .trialLimitReached: paywall = .trialScansUsed
        }
    }

    private func read(_ images: [UIImage]) async {
        await readPages(count: images.count) { images[$0] }
    }

    private func readPages(count: Int, imageAt: (Int) -> UIImage) async {
        guard count > 0 else { return }
        guard plus.decide(.scan) == .allowed else {
            phase = .choose
            allowScan {}
            return
        }
        message = nil
        phase = .reading
        sourcePreviews = []
        pageCount = count
        do {
            var found: [ScannedWordCandidate] = []
            var seen: [String: [ReviewedScanWord]] = [:]
            for index in 0..<count {
                try Task.checkCancellation()
                let image = imageAt(index)
                if index < 8, let thumbnail = await thumbnail(image) { sourcePreviews.append(thumbnail) }
                let candidates = try await TextRecognizer.candidates(in: [image], suggester: dictionary())
                for var candidate in candidates {
                    let key = ScanImportPlan.wordKey(candidate.word)
                    guard !(seen[key] ?? []).contains(where: { ScanImportPlan.sameEntry($0, candidate.reviewedWord) }) else { continue }
                    seen[key, default: []].append(candidate.reviewedWord)
                    candidate.key = "page\(index)-\(candidate.key)"
                    found.append(candidate)
                }
            }
            try Task.checkCancellation()
            showReview(found)
            if !found.isEmpty { plus.noteScanUsed() }
        } catch is CancellationError {
            return
        } catch {
            message = S.readFailed
            phase = .choose
        }
    }

    private func thumbnail(_ image: UIImage) async -> UIImage? {
        await withCheckedContinuation { continuation in
            image.prepareThumbnail(of: CGSize(width: 1200, height: 1600)) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func startReading(_ images: [UIImage]) {
        scanTask?.cancel()
        scanTask = Task { await read(images) }
    }

    private func loadSelectedPhoto() {
        guard let provider = pendingPhotos.first else { return }
        pendingPhotos = []
        scanTask?.cancel()
        message = nil
        phase = .loadingPhoto
        scanTask = Task {
            do {
                let image = try await ScanPhotoLoader.image(from: provider)
                await read([image])
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                message = S.photoLoadFailed
                phase = .choose
            }
        }
    }

    private func dictionary() -> WordSuggester {
        if let suggester { return suggester }
        let built = WordSuggester(words: model.vocabularyWords.map(\.word))
        suggester = built
        return built
    }

    private func showReview(_ candidates: [ScannedWordCandidate]) {
        let suggester = dictionary()
        rows = candidates.enumerated().map { index, candidate in
            Row(id: "\(candidate.key)-r\(index)", include: !candidate.needsReview, word: candidate.word, partOfSpeech: candidate.partOfSpeech, meaning: candidate.meaningZh,
                suggestedWord: suggester.correction(for: candidate.word), needsReview: candidate.needsReview)
        }
        target = .new
        phase = .review
    }

    // MARK: Review

    private var review: some View {
        let plan = importPlan
        let count = plan.additions.count
        let decisions = Dictionary(uniqueKeysWithValues: zip(selectedRows.map(\.id), plan.dispositions))
        return Form {
            if !sourcePreviews.isEmpty {
                Section {
                    Button { previewOpen = true } label: {
                        Label(L.t("對照原始頁面", "Compare with source"), systemImage: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("scan-source-preview")
                    if pageCount > sourcePreviews.count {
                        Text(L.t("已辨識全部 \(pageCount) 頁，預覽顯示前 \(sourcePreviews.count) 頁。", "All \(pageCount) pages were read. Preview shows the first \(sourcePreviews.count)."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                if rows.isEmpty {
                    Text(S.noneFound).foregroundStyle(.secondary)
                }
                ForEach($rows) { $row in
                    HStack(alignment: .top, spacing: 12) {
                        Button { row.include.toggle() } label: {
                            Image(systemName: row.include ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(row.include ? Palette.accent : Palette.tertiaryLabel)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 6) {
                            if let decision = decisions[row.id] { importStatus(decision, id: row.id) }
                            if row.needsReview {
                                Label(L.t("相近拼字，請對照原圖後勾選", "Similar readings: compare with the source before selecting"), systemImage: "exclamationmark.circle")
                                    .font(.caption).foregroundStyle(Palette.review)
                            }
                            HStack {
                                TextField(S.word, text: $row.word)
                                    .font(.rounded(.headline))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .accessibilityIdentifier("scan-word-\(row.id)")
                                    .onChange(of: row.word) { _, _ in row.suggestedWord = nil }
                                TextField(S.pos, text: $row.partOfSpeech)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.accent)
                                    .frame(minWidth: 64, maxWidth: 100)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            TextField(S.meaning, text: $row.meaning)
                                .font(.subheadline)
                                .accessibilityIdentifier("scan-meaning-\(row.id)")
                            if row.id.contains("-ai-") {
                                Label(S.organizedByAI, systemImage: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let original = row.originalWord {
                                Button {
                                    row.word = original
                                    row.originalWord = nil
                                } label: {
                                    Label(S.corrected(original), systemImage: "wand.and.stars")
                                        .font(.caption)
                                        .foregroundStyle(Palette.review)
                                }
                                .buttonStyle(.plain)
                            }
                            if let suggestion = row.suggestedWord, suggestion != row.word {
                                Button {
                                    row.originalWord = row.word
                                    row.word = suggestion
                                    row.suggestedWord = nil
                                } label: {
                                    Label(L.t("改用建議拼字「\(suggestion)」", "Use suggested spelling: \(suggestion)"), systemImage: "text.badge.checkmark")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("scan-suggestion-\(row.id)")
                            }
                        }
                    }
                    .opacity(row.include ? 1 : 0.5)
                }
                .onDelete { rows.remove(atOffsets: $0) }
                Button {
                    rows.append(Row(id: "manual-\(UUID().uuidString)", word: "", partOfSpeech: "", meaning: ""))
                } label: {
                    Label(S.addRow, systemImage: "plus")
                }
            } header: {
                Text(S.found(rows.count))
            } footer: {
                Text(S.reviewHint)
            }

            Section(S.saveTo) {
                Picker(S.saveTo, selection: $target) {
                    Text(S.newBank).tag(Target.new)
                    ForEach(destinationBanks) { set in
                        Text(set.name).tag(Target.existing(set.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("scan-destination")
                if target == .new {
                    TextField(S.bankName, text: $newBankName)
                        .accessibilityIdentifier("scan-bank-name")
                }
            }

            Section {
                if plan.duplicateCount > 0 {
                    Text(L.t("\(plan.duplicateCount) 筆相同拼字與意思不會再次加入；同字不同義會保留。", "\(plan.duplicateCount) identical entries will be skipped. Different meanings are kept."))
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("scan-duplicates-summary")
                }
                Button {
                    save()
                } label: {
                    Text(S.save(count))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(count == 0)
                .accessibilityIdentifier("scan-save")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func importStatus(_ decision: ScanImportPlan.Disposition, id: String) -> some View {
        switch decision {
        case .duplicateInBank:
            Label(L.t("此字庫已有相同單字與意思，略過", "Already in this bank; will be skipped"), systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("scan-duplicate-\(id)")
        case .duplicateInScan:
            Label(L.t("與本次勾選的單字重複，略過", "Duplicate in this scan; will be skipped"), systemImage: "doc.on.doc")
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("scan-duplicate-\(id)")
        case .additionalMeaning:
            Label(L.t("同字不同義或詞性，保留為另一筆", "Different meaning or word class; kept separately"), systemImage: "text.badge.plus")
                .font(.caption).foregroundStyle(Palette.accent).accessibilityIdentifier("scan-new-meaning-\(id)")
        case .newWord, .incomplete:
            EmptyView()
        }
    }

    private func save() {
        let reviewed = rows.filter(\.include).map {
            ReviewedScanWord(meaningZh: $0.meaning, partOfSpeech: $0.partOfSpeech, word: $0.word)
        }
        let result: (setId: String, added: Int, name: String)?
        switch target {
        case .new: result = model.saveScannedWords(reviewed, newBankName: newBankName)
        case let .existing(id): result = model.saveScannedWords(reviewed, intoSet: id)
        }
        if let result {
            phase = .saved(count: result.added, name: result.name)
        }
    }

    // MARK: Saved

    private func saved(count: Int, name: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Palette.known)
            Text(S.savedTitle).font(.rounded(.title2, weight: .bold))
                .accessibilityIdentifier("scan-saved")
            Text(S.savedText(count, name))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if case .trial = plus.access {
                Button { paywall = .general } label: {
                    Label(P.scansLeft(plus.policy.trialScansLeft), systemImage: "sparkles")
                        .font(.footnote.weight(.semibold))
                }
            }
            Button {
                onStudy()
            } label: {
                Label(S.startStudy, systemImage: "book.fill").font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("scan-start-study")
            Button {
                rows = []
                pasted = ""
                phase = .choose
            } label: {
                Label(S.scanAnother, systemImage: "doc.text.viewfinder").font(.headline).frame(maxWidth: .infinity)
            }
            .secondaryAction()
        }
        .card(radius: Metrics.wordCardRadius, padding: 24)
        .padding(Metrics.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Scan screen copy (English-word mode).
private enum S {
    static var title: String { L.t("掃描單字表", "Scan a word list") }
    static var intro: String { L.t("掃描或選一張單字表照片，App 會在手機上讀出英文單字和紙上寫的中文意思，印刷或手寫都可以。照片不會上傳。", "Scan or pick a photo of a word list. The app reads each English word and the Chinese meaning written on the page, printed or handwritten. Photos never leave your iPhone.") }
    static var takePhoto: String { L.t("拍照", "Take Photo") }
    static var scanDocument: String { L.t("掃描單字表（可多頁、手寫也行）", "Scan a word list (several pages, handwriting OK)") }
    static var organizedByAI: String { L.t("由 Apple Intelligence 從頁面整理，請確認", "Organised from the page by Apple Intelligence; please check") }
    static func corrected(_ original: String) -> String { L.t("還原為「\(original)」", "Restore \u{201C}\(original)\u{201D}") }
    static var choosePhoto: String { L.t("從相簿選擇", "Choose Photo") }
    static var pasteTitle: String { L.t("或貼上文字", "Or paste text") }
    static var pasteHint: String { L.t("在「照片」App 長按文字即可拷貝（原況文字），再貼到這裡", "In Photos, touch and hold text to copy it (Live Text), then paste it here") }
    static var pastePlaceholder: String { L.t("abandon v. 放棄\nbenefit n. 好處", "abandon v. 放棄\nbenefit n. 好處") }
    static var readPasted: String { L.t("讀取貼上的文字", "Read pasted text") }
    static var reading: String { L.t("正在手機上辨識…", "Reading on your iPhone…") }
    static var loadingPhoto: String { L.t("正在載入照片…", "Loading your photo…") }
    static var photoLoadFailed: String { L.t("無法載入這張照片。若照片在 iCloud，請確認網路連線後再試一次，或改選另一張照片。", "Could not load this photo. If it is in iCloud, check your connection and try again, or choose another photo.") }
    static var readingSmart: String { L.t("正在手機上辨識並整理…", "Reading and organising on your iPhone…") }
    static var readFailed: String { L.t("辨識失敗，請換一張更清楚的照片再試一次。", "Could not read that photo. Try a clearer one.") }
    static func found(_ count: Int) -> String { L.t("找到 \(count) 個單字", "\(count) words found") }
    static var reviewHint: String { L.t("儲存前可以直接修改英文或中文；取消勾選的不會存入。左滑可以刪除。", "Fix any word or meaning before saving. Unchecked rows are skipped; swipe left to delete.") }
    static var noneFound: String { L.t("沒有找到成對的英文和中文意思。可以換一張更清楚的照片，或用「新增一列」手動加入。", "No word and meaning pairs were found. Try a clearer photo, or add rows by hand.") }
    static var word: String { L.t("英文", "English") }
    static var meaning: String { L.t("中文意思", "Chinese meaning") }
    static var pos: String { L.t("詞性", "Part") }
    static var addRow: String { L.t("新增一列", "Add row") }
    static var saveTo: String { L.t("存到", "Save to") }
    static var newBank: String { L.t("新字庫", "New bank") }
    static var bankName: String { L.t("字庫名稱", "Bank name") }
    static func save(_ count: Int) -> String { L.t("存入字庫（\(count) 個）", "Save \(count) words") }
    static var rescan: String { L.t("重新掃描", "Scan again") }
    static var savedTitle: String { L.t("已存入字庫", "Saved") }
    static func savedText(_ count: Int, _ name: String) -> String { L.t("\(count) 個單字已加入「\(name)」，學習、測驗和字庫都已切換到這個字庫。", "\(count) words added to \u{201C}\(name)\u{201D}. Study, quizzes and Words now use this bank.") }
    static var startStudy: String { L.t("開始學習", "Start studying") }
    static var scanAnother: String { L.t("再掃一張", "Scan another") }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
