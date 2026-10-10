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
    @State private var message: String?
    @State private var target: Target = .new
    @State private var newBankName = WordBanks.defaultScanBankName()

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
                    ProgressView(S.reading)
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
            CameraPicker { image in Task { await read(image) } }
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await read(image)
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

                if CameraPicker.isAvailable {
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

    private func read(_ image: UIImage) async {
        message = nil
        phase = .reading
        do {
            let lines = try await TextRecognizer.lines(in: image)
            showReview(ScanParser.parse(lines))
        } catch {
            message = S.readFailed
            phase = .choose
        }
    }

    private func showReview(_ candidates: [ScannedWordCandidate]) {
        rows = candidates.map { Row(id: $0.key, word: $0.word, partOfSpeech: $0.partOfSpeech, meaning: $0.meaningZh) }
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
    static let title = "掃描單字表"
    static let intro = "拍下或選一張單字表照片，App 會在手機上讀出英文單字和紙上印的中文意思。照片不會上傳。"
    static let takePhoto = "拍照"
    static let choosePhoto = "從相簿選擇"
    static let pasteTitle = "或貼上文字"
    static let pasteHint = "在「照片」App 長按文字即可拷貝（原況文字），再貼到這裡"
    static let pastePlaceholder = "abandon v. 放棄\nbenefit n. 好處"
    static let readPasted = "讀取貼上的文字"
    static let reading = "正在手機上辨識…"
    static let readFailed = "辨識失敗，請換一張更清楚的照片再試一次。"
    static func found(_ count: Int) -> String { "找到 \(count) 個單字" }
    static let reviewHint = "儲存前可以直接修改英文或中文；取消勾選的不會存入。左滑可以刪除。"
    static let noneFound = "沒有找到成對的英文和中文意思。可以換一張更清楚的照片，或用「新增一列」手動加入。"
    static let word = "英文"
    static let meaning = "中文意思"
    static let pos = "詞性"
    static let addRow = "新增一列"
    static let saveTo = "存到"
    static let newBank = "新字庫"
    static let bankName = "字庫名稱"
    static func save(_ count: Int) -> String { "存入字庫（\(count) 個）" }
    static let rescan = "重新掃描"
    static let savedTitle = "已存入字庫"
    static func savedText(_ count: Int, _ name: String) -> String { "\(count) 個單字已加入「\(name)」，學習、測驗和字庫都已切換到這個字庫。" }
    static let startStudy = "開始學習"
    static let scanAnother = "再掃一張"
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
