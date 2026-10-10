import PhotosUI
import SwiftUI
import Word7000Core

/// Photograph (or paste) a vocabulary sheet, check what was read, and save it
/// as a word bank. The meaning saved is the one printed on the paper.
struct ScanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onStudy: () -> Void

    enum Phase: Equatable {
        case choose
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
    }

    enum Target: Hashable {
        case new
        case existing(String)
    }

    @State private var phase: Phase = .choose
    @State private var rows: [Row] = []
    @State private var pasted = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var cameraOpen = false
    @State private var documentScannerOpen = false
    @State private var suggester: WordSuggester?
    @State private var message: String?
    @State private var target: Target = .new
    @State private var newBankName = WordBanks.defaultScanBankName(chineseMode: L.mode == .chinese)

    private var scanBanks: [CustomVocabSet] {
        model.customSets.sets.filter { set in set.wordIds.contains(where: WordBanks.isScannedWordId) }
    }

    private var savableCount: Int {
        rows.filter { $0.include && !$0.word.trimmed.isEmpty && !$0.meaning.trimmed.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .choose: chooser
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
                }
                if phase == .review {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(S.rescan) { phase = .choose; rows = [] }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $cameraOpen) {
            CameraPicker { image in Task { await read([image]) } }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $documentScannerOpen) {
            DocumentScanner { pages in Task { await read(pages) } }
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await read([image])
                } else {
                    message = S.readFailed
                }
                photoItem = nil
            }
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                if DocumentScanner.isAvailable {
                    Button { documentScannerOpen = true } label: {
                        Label(S.scanDocument, systemImage: "doc.viewfinder.fill")
                    }
                    .accessibilityIdentifier("scan-document")
                } else if CameraPicker.isAvailable {
                    Button { cameraOpen = true } label: {
                        Label(S.takePhoto, systemImage: "camera.fill")
                    }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(S.choosePhoto, systemImage: "photo.on.rectangle")
                }
                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.review)
                }
            }

            Section {
                TextField(S.pastePlaceholder, text: $pasted, axis: .vertical)
                    .lineLimit(4...10)
                    .font(.body.monospaced())
                Button(S.readPasted) {
                    let found = ScanParser.parse(ScanParser.lines(fromPlainText: pasted))
                    showReview(found)
                }
                .disabled(pasted.trimmed.isEmpty)
            } header: {
                Text(S.pasteTitle)
            } footer: {
                Text(S.pasteHint)
            }
        }
    }

    private func read(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        message = nil
        phase = .reading
        do {
            showReview(try await TextRecognizer.candidates(in: images, suggester: dictionary()))
        } catch {
            message = S.readFailed
            phase = .choose
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
        rows = candidates.map { candidate in
            if let corrected = suggester.correction(for: candidate.word) {
                return Row(id: candidate.key, word: corrected, partOfSpeech: candidate.partOfSpeech, meaning: candidate.meaningZh, originalWord: candidate.word)
            }
            return Row(id: candidate.key, word: candidate.word, partOfSpeech: candidate.partOfSpeech, meaning: candidate.meaningZh)
        }
        if let latest = scanBanks.last { target = .existing(latest.id) } else { target = .new }
        phase = .review
    }

    // MARK: Review

    private var review: some View {
        Form {
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
                            HStack {
                                TextField(S.word, text: $row.word)
                                    .font(.rounded(.headline))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField(S.pos, text: $row.partOfSpeech)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 64)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            TextField(S.meaning, text: $row.meaning)
                                .font(.subheadline)
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
                    ForEach(scanBanks) { set in
                        Text(set.name).tag(Target.existing(set.id))
                    }
                }
                if target == .new {
                    TextField(S.bankName, text: $newBankName)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Text(S.save(savableCount))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(savableCount == 0)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
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
            Text(S.savedText(count, name))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                dismiss()
                onStudy()
            } label: {
                Label(S.startStudy, systemImage: "book.fill").font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
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
    static func corrected(_ original: String) -> String { L.t("原本讀成「\(original)」，已對照字典修正。點這裡還原", "Read as \u{201C}\(original)\u{201D}; matched to the dictionary. Tap to undo") }
    static var choosePhoto: String { L.t("從相簿選擇", "Choose Photo") }
    static var pasteTitle: String { L.t("或貼上文字", "Or paste text") }
    static var pasteHint: String { L.t("在「照片」App 長按文字即可拷貝（原況文字），再貼到這裡", "In Photos, touch and hold text to copy it (Live Text), then paste it here") }
    static var pastePlaceholder: String { L.t("abandon v. 放棄\nbenefit n. 好處", "abandon v. 放棄\nbenefit n. 好處") }
    static var readPasted: String { L.t("讀取貼上的文字", "Read pasted text") }
    static var reading: String { L.t("正在手機上辨識…", "Reading on your iPhone…") }
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
