import SwiftUI
import Word7000Core

/// The classic layout's Language learning tab: the chapters of the built-in
/// words as a path, opened in order. The chapter being read opens today's
/// words as four big tiles (cards, writing, quiz, speaking: ChapterPageView); a
/// chapter read through, or one the level test skipped, opens a round of its
/// words to review; the chapters after the one being read stay locked until
/// it is read through (four in five of its words known).
struct LearningPathView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var start: (Activity) -> Void
    /// Opens the Words tab.
    var showWords: () -> Void = {}

    /// Where a chapter stands on the path.
    enum Stop: Equatable {
        /// Read through: four in five of its words known.
        case read
        /// Below where the level test started, not read through.
        case skipped
        /// The one being read: today's words come from here.
        case current
        case locked
    }

    var body: some View {
        let chapters = model.shelfChapters
        let current = model.readingChapter
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summary(chapters)
                if current == nil {
                    todayLink(note: outsideNote(chapters))
                }
                ForEach(chapters.indices, id: \.self) { index in
                    row(index, chapter: chapters[index], stop: stop(index, chapters[index], current: current))
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background { AmbientBackground(tint: Palette.accent) }
        .navigationTitle(L.t("語言學習", "Language learning"))
        .navigationDestination(for: Int.self) { chapter in
            ChapterPageView(chapter: chapter, start: start)
        }
    }

    private func stop(_ index: Int, _ chapter: ShelfChapter, current: Int?) -> Stop {
        if index == current { return .current }
        if chapter.fraction >= MasteryShelf.readFraction { return .read }
        if let start = model.placementStart, index < start - 1 { return .skipped }
        // Nothing being read (another word bank, or every chapter read): the
        // chapters can still be reviewed but not started out of order.
        return current.map { index < $0 ? .skipped : .locked } ?? .locked
    }

    // MARK: Top

    private func summary(_ chapters: [ShelfChapter]) -> some View {
        let mastered = chapters.reduce(0) { $0 + $1.mastered }
        let total = chapters.reduce(0) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: 4) {
            Text(L.t("已會 \(mastered.formatted()) / \(total.formatted()) 個字", "\(mastered.formatted()) of \(total.formatted()) words known"))
                .font(.display(.title3, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(L.t("一章一章往下讀；這一章會了八成，下一章就打開。", "One chapter at a time: know four in five of its words and the next one opens."))
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .accessibilityIdentifier("path-summary")
    }

    /// Why no chapter is open, when none is.
    private func outsideNote(_ chapters: [ShelfChapter]) -> String {
        if model.settings.activeBankId != WordBanks.coreBankId {
            return L.t("你現在學的是「\(model.bankName)」，章節只用在內建單字。今天的單字在這裡：",
                       "You're studying \"\(model.bankName)\"; chapters are for the built-in words. Today's words are here:")
        }
        return L.t("每一章都讀完了！今天的單字在這裡：", "Every chapter is read! Today's words are here:")
    }

    /// Today's four steps, outside the chapters.
    private func todayLink(note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                ChapterPageView(chapter: nil, start: start)
            } label: {
                HStack {
                    Image(systemName: "rectangle.on.rectangle.angled")
                    Text(L.t("今天的單字", "Today's words"))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background { PremiumSurface(radius: 16) }
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("path-today")
        }
    }

    // MARK: A chapter

    @ViewBuilder
    private func row(_ index: Int, chapter: ShelfChapter, stop: Stop) -> some View {
        let label = rowLabel(index, chapter: chapter, stop: stop)
        switch stop {
        case .current:
            NavigationLink(value: index) { label }
                .buttonStyle(SoftPressStyle())
                .accessibilityIdentifier("path-chapter-\(index + 1)")
        case .read, .skipped:
            Button { review(index) } label: { label }
                .buttonStyle(SoftPressStyle())
                .accessibilityHint(L.t("複習這一章的字", "Review this chapter's words"))
                .accessibilityIdentifier("path-chapter-\(index + 1)")
        case .locked:
            label
                .opacity(0.55)
                .accessibilityIdentifier("path-chapter-\(index + 1)")
        }
    }

    private func rowLabel(_ index: Int, chapter: ShelfChapter, stop: Stop) -> some View {
        let current = stop == .current
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(badgeFill(stop))
                Image(systemName: badgeIcon(stop))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(stop == .locked ? Palette.secondaryLabel : .white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(L.t("第 \(index + 1) 章", "Chapter \(index + 1)"))
                        .font(.display(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(status(stop))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(current ? Palette.accent : Palette.secondaryLabel)
                }
                ProgressView(value: chapter.fraction)
                    .tint(stop == .read ? Palette.known : Palette.accent)
                Text(L.t("已會 \(chapter.mastered) / \(chapter.total) 個字", "\(chapter.mastered) of \(chapter.total) known"))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryLabel)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            if stop != .locked {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(current ? Palette.accent : Palette.secondaryLabel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, current ? 16 : 12)
        .background {
            PremiumSurface(radius: 18)
                .overlay {
                    if current {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Palette.accent, lineWidth: 2)
                    }
                }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func status(_ stop: Stop) -> String {
        switch stop {
        case .read: L.t("讀完了", "Read")
        case .skipped: L.t("程度測驗跳過", "Skipped")
        case .current: L.t("正在讀", "Reading now")
        case .locked: L.t("還沒開", "Locked")
        }
    }

    private func badgeIcon(_ stop: Stop) -> String {
        switch stop {
        case .read: "checkmark"
        case .skipped: "forward.fill"
        case .current: "book.fill"
        case .locked: "lock.fill"
        }
    }

    private func badgeFill(_ stop: Stop) -> Color {
        switch stop {
        case .read: Palette.known
        case .skipped: Palette.chinese
        case .current: Palette.accent
        case .locked: Palette.secondaryLabel.opacity(0.18)
        }
    }

    /// A round of the chapter's words: those studied, the most due first;
    /// for a chapter never studied (one the level test skipped), its first words.
    private func review(_ index: Int) {
        let ids = model.chapterWordIds(index)
        let studied = ids.filter { (model.progress.words[$0]?.status ?? .new) != .new }
        model.startStudySession(onlyIds: studied.isEmpty ? ids : studied, limit: model.progress.dailyTarget)
        start(.study)
    }
}
