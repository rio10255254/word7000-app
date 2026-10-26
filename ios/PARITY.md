# Word7000 — Native SwiftUI Parity Spec

Implementation-ready description of the shipping Expo / React Native app (repo `word7000-app`, app version **1.5.0**, last TestFlight build **25**) so a Swift engineer can rebuild it in SwiftUI **without reading the TypeScript**. Where porting a file 1:1 is the safest route (parsers, PRNG, merge rules), the file is named as the reference and its tests are the acceptance suite.

Source of truth used for this document: `App.tsx` (14,954 lines; the whole app state lives in `AppDataProvider`), `src/app/**` (expo-router routes), `src/lib/**`, `src/components/**`, `src/liveActivity/StreakLiveActivity.tsx`, `src/design/iosVisualSystem.ts`, `modules/word-scanner/**`, `supabase/**`, `app.json`, `eas.json`, `package.json`, and the native sources in `node_modules` (`@react-native-async-storage/async-storage@2.2.0`, `expo-widgets@57.0.15`, `@supabase/supabase-js@2.108.x`).

> Note: `AGENTS.md` mentions Expo SDK 56, but `package.json` pins **Expo SDK 57** (`expo ~57.0.18`, RN 0.86.3, React 19.2.3). Irrelevant for the Swift port except for reading native module sources.

---

## 0. Ground rules, identifiers and a naming trap

### 0.1 Identifiers the native app MUST keep

| Item | Value | Why |
|---|---|---|
| Bundle ID | `com.rio.word7000` | Same app record → in-place upgrade, same sandbox container (needed to migrate AsyncStorage data, §6). |
| App Store Connect app id | `6786934889` | `eas.json` submit config. |
| Marketing version | `1.5.0` (bump as you like) | `app.json`. |
| Build number (`CFBundleVersion`) | must be **> 25** | Last RN TestFlight build is 25; update policy compares integers (§10.1). |
| URL scheme | `word7000` | OAuth return `word7000://auth/callback`, Live Activity tap `word7000://study`. |
| Sign in with Apple capability | on (`usesAppleSignIn: true`) | |
| Devices / orientation | iPhone only (`supportsTablet: false`), portrait only | |
| Appearance | automatic (light/dark), user-overridable (§9) | |
| Widget extension | RN build used target `ExpoWidgetsTarget`, bundle id `com.rio.word7000.ExpoWidgetsTarget`, App Group `group.com.rio.word7000`, `NSSupportsLiveActivities = YES`, push notifications enabled | Keep the extension bundle id and the APNs topic `com.rio.word7000.push-type.liveactivity` so the server keeps working (§8). |
| ActivityKit attributes type name | `LiveActivityAttributes` with `ContentState { name: String; props: String }` and static attribute `url: String?` | The server push sends `"attributes-type": "LiveActivityAttributes"` (§8.4). |
| Encryption flag | `ITSAppUsesNonExemptEncryption = false` | |
| Photo/camera usage strings | see §5.4 | Microphone permission explicitly **not** requested. |

### 0.2 The `studyMode` naming trap (read this first)

`studyMode` is named after **the language being learned**, not the UI language:

| `studyMode` value | Learner | UI language | Card front | Answer side |
|---|---|---|---|---|
| `'english'` (**default**) | Taiwanese learner studying English | Traditional Chinese (zh-TW) | English word | Chinese meaning |
| `'chinese'` | English speaker studying Chinese | English | Chinese meaning (+ pinyin) | English word |

So every copy object keyed `english:` contains **Chinese strings**, and every object keyed `chinese:` contains **English strings**. In this document "zh-TW UI" = `english` mode, "English UI" = `chinese` mode. Persisted value: storage key `word7000-study-mode-v1` = `"english"` | `"chinese"` (anything else → `english`). Full list of what flips is in §2.

### 0.3 Date conventions

* "today" is always the **device-local** calendar date formatted `YYYY-MM-DD` (`localDateKey()` = local time minus TZ offset, ISO date). It is re-evaluated on a timer and whenever the app becomes active (§8.2), so crossing midnight while open rolls the day.
* Day arithmetic on these strings (`addDays`, "is yesterday") is done on UTC day numbers of the string, i.e. pure calendar math, no DST issues.
* Timestamps (`statusUpdatedAt`, `favoritedAt`, `updatedAt`, …) are `Date().toISOString()` (UTC, `2026-10-10T08:05:00.000Z`), compared **as strings** in most merge rules.

---

## 1. Screens & navigation

### 1.1 Boot sequence

1. Native splash (background `#2563EB`, `splash-icon.png` 180 pt wide, contain) is held until **both** local storage is hydrated and the bundled vocabulary is loaded; fades out over 360 ms.
2. Storage hydration reads every AsyncStorage key that starts with `word7000-` into an in-memory dictionary (all later reads are synchronous from that cache; writes go to the cache immediately and are persisted asynchronously, serialized per key). A 10 s timeout marks boot as failed.
3. While not ready a boot screen shows (only visible if hydration is slow): `BrandMark` 82 pt, title `Word7000`, text `正在準備你的學習紀錄...`. On failure the text becomes `無法完成啟動，但你的學習紀錄仍安全保存在裝置中。` plus a blue button `重新開啟 Word7000` (reloads the JS bundle; native equivalent: retry load).
4. Global render-crash fallback (error boundary): BrandMark 64, title `Word7000 暫時無法顯示`, body `你的學習紀錄仍保存在裝置中。重新開啟即可繼續。`, English line `Your progress is safe. Reopen the app to continue.`, button `重新開啟`.
5. Then the data layer starts (§7.3 bootstrap: load local progress → restore/create Supabase session → merge cloud).

In Swift: load the 7000-word JSON + migrated store before showing the tab UI; keep the launch screen up until then.

### 1.2 Navigation map

```
Root NavigationStack (no nav bar on pushed screens; each pushed screen draws its own pill "‹ Back" button)
├── TabView (5 tabs, native tab bar; on iOS 26+ with Liquid Glass: minimize on scroll down)
│   ├── home     "首頁" / "Home"      SF: house / house.fill
│   ├── study    "學習" / "Chinese"   SF: book / book.fill          ← note: English-UI label is "Chinese"
│   ├── quiz     "測驗" / "Quiz"      SF: target
│   ├── library  "字庫" / "Library"   SF: books.vertical / books.vertical.fill
│   └── profile  "我的" / "Me"        SF: person / person.fill
│   (Each tab shows a compact, non-large, non-transparent nav header whose title = the tab label, 21 pt bold, no hairline.)
├── push: library/[wordId]?source=home|library   Word detail
├── push: sets                                    My Sets (custom sets manager)        [requires permanent account]
├── push: scan                                    Scan a word sheet                    [requires permanent account]
├── push: settings                                Settings
├── push: stats                                   Personal learning analytics
└── route auth/callback → immediately redirects to "/" (OAuth return target only)
Unknown routes → "/".
```

Push animation: standard iOS push (350 ms) with full-screen swipe-back on non-legacy iOS (the RN app treats iOS 16–18 as "legacy" and uses the default push there); with Reduce Motion: 120 ms fade. Tab press triggers a Medium impact haptic (not in Low Power Mode).

Modal / overlay surfaces (all owned by the root, shown above tabs):

| Surface | Trigger | Presentation |
|---|---|---|
| Quick dictionary | Home search row | iOS page sheet (`.sheet`, swipe to dismiss), keyboard focused after 110 ms |
| Word-bank picker | Any "字庫 / Bank" bar | bottom sheet with dimmed backdrop (fade) |
| Account-upgrade sheet | Any gated feature for guests (§7.6) | full-screen transparent modal, spring-in bottom panel |
| Add-to-set picker | "+" on a word (study card, library row, word detail) | centered card overlay (spring) |
| Study-mode switch overlay | Home "switch mode" row | non-interactive full-screen overlay, ~690 ms |
| Update-required overlay | §10.1 | blocking full-screen overlay |
| Delete-account confirm | Settings | `UIAlertController` (Cancel / destructive) |
| Settings theme cross-fade | Changing appearance in Settings | full-screen color fade (§9.6) |
| Install guide | **web only — drop** | |

Gating redirects: opening `sets` or `scan` without a permanent (non-guest) account immediately shows the account-upgrade sheet (`customSets` reason) and redirects to the Library tab. Word detail with an unknown id → Home.

### 1.3 Shared building blocks (used on several screens)

**Word-bank bar** (`WordBankBar`) — a full-width grouped row at the top of Home, Study, Quiz and Library:
`[icon] 字庫/Bank  <bank name (bold rounded 16, 1 line, flex)>  <"N 個" / "N words">  ⌄`.
Icon = `doc.text.viewfinder` if the active bank contains scanned words, else `square.stack.3d.up.fill`, tinted accent, on an accent-soft 28 pt rounded square. Tap → bank picker sheet. Accessibility label `"<bankLabel> <name>"`, hint `bankPickerHint`.
On Study and Quiz the bar is followed (same row) by a square **filter button** (`line.3.horizontal.decrease`): accent glyph on surface; when any filter is non-default OR the panel is open it becomes a solid accent square with a white glyph. Accessibility: `filterButtonLabel`, `expanded` state.

**Filter panel** (`FilterControlPanel`) — collapsible card with animated height (open 360 ms ease-out-cubic, close 290 ms ease-in-out; 120 ms when conserving resources). Content sections, each a horizontally scrolling chip row:
1. **Status** (`filterStatus`) chips `all / favorites / review / mastered / new` (labels in `filterLabels`). If the user is not signed in permanently, the Favorites chip shows a small lock and tapping it opens the upgrade sheet (`favorites` reason) instead of selecting.
2. **Level** (`filterLevel`) chips: `全部分級`/`All Levels` then one chip per distinct `group` of the active bank's words, in first-appearance order, labeled with `group.replace('Core ', 'L')` → `L1`…`L14`, `Custom`, `Scan`. A1y label `levelAccessibility(label)`.
3. **First letter** (`initialTitle` from `modeCopy`: `字首` / `First Letter`): `全部`/`All` then `A`…`Z` (34 pt round chips). A1y `initialAccessibility`.
4. **Sort** (Library only, `filterSort`): `default` → `sortDefault`, `alphabetical` → `sortAlphabetical`.

Study/Quiz use the "options only" variant (shown only when open; first line is an inline summary `"<status> / <level> / <initial> · <count> <filterCountUnit>"`). Library uses the variant with a tappable summary header: title `libraryFilterTitle`, subtitle `"<level> / <initial> / <sort> · <count> <filterCountUnit>"`, trailing `slider.horizontal` + chevron (rotates when open). Selected chip = solid accent bg, white text; unselected = `rgba(120,120,128,0.12)` (dark `0.24`) bg, secondary text 13 pt medium.

When the visible bank changes, any level filter not present in the new bank resets to `all` (study, quiz and library independently).

**Favorite glyph**: star 18–21 pt; filled `#FF9500` when favorited, else outline secondary gray. **Add-to-set glyph**: `plus.square`-style icon in `#007AFF`. When the user is not permanently signed in both show a tiny lock badge (8 pt lock in a 12 pt circle at bottom-right) and haptics are suppressed; tapping still triggers the upgrade sheet.

**Empty-state card**: grouped surface, title (rounded 15 bold) + caption (13, secondary).

**Pill back button** (pushed screens): left-aligned capsule `‹ <label>` on a surface background, 15 pt semibold.

### 1.4 Home tab

Vertical stack (16 pt side padding, 14 pt gaps, top padding 10):

1. **Word-bank bar** (§1.3).
2. **Today hero card** (radius 20, padding 16):
   * Left: **progress ring** 112 pt, stroke 11, round caps, track `rgba(120,120,128,0.16)` (dark 0.32), progress color = accent, or green when goal is done. Center: `studiedToday` (SF Rounded 32 heavy, tabular) over `/ <dailyTarget>` (rounded 13 semibold, tertiary).
   * Right column: title `heroTitle(dailyTarget)` (two lines, contains `\n`) or `heroDoneTitle` when `studiedToday ≥ dailyTarget` (SF Rounded 24/30 bold); plan line `todayPlan(due, newLeft)` where `due = stats.due` (words due today in the active bank) and `newLeft = max(0, dailyTarget − studiedToday)`; when `streak > 0` an orange-soft capsule with `flame.fill` (orange) and `streakDays(streak)` (13 bold, `#C25E00`).
   * Full-width **pill button** (height 52, radius 999, accent, `book.fill` icon): text = `extraAction` if goal done, else `continueAction` if `studiedToday > 0`, else `primaryAction`. Tap: if the current study session is finished, build a fresh session; then switch to the Study tab.
3. **Stats strip** (one grouped surface, three equal columns separated by hairlines; whole strip is one button → pushes `stats`): `streak` value in orange, `mastered` value in green, `reviewDueToday` value = `stats.due` in accent if > 0 else label color. Values SF Rounded 22 bold, labels 12 secondary.
4. **Dictionary launcher** row (accent-soft bg `#EAF4FF` / dark `#1C1C1E`, radius 20, min height 60): magnifier icon in a small tile + placeholder text `searchPlaceholder` (1 line). Tap → Quick dictionary sheet.
5. **Action group** (one grouped surface with inset dividers), each row 54 pt min, 32 pt icon tile + rounded 15 semibold title + chevron `#C7C7CC`:
   * `reviewList` (orange-soft tile, `arrow.counterclockwise`), trailing count = `stats.review` if > 0. Tap: set Library status filter to `review`, switch to Library tab.
   * `quickQuiz` (accent tile, `target`). Tap: switch to Quiz tab (does not auto-start).
   * Mode switch: title `toggleTitle` (`Switch to Chinese words` in zh-TW UI, `切到英文單字` in English UI), a11y hint `toggleText`, icon `character.bubble.fill` tinted accent (zh UI) or indigo (English UI). Tap → §2 toggle with overlay.
6. **Update check row** (§10.1): cloud icon tile, title `updateCheckTitle`, 2-line detail (status-dependent, see table in §10.1), trailing capsule with spinner / check / download / retry icon + status text. Disabled while checking.

**Quick dictionary sheet**: title `dictionaryLookup`; when a query exists, subtitle `searchMeta(query, n)`; close button (`xmark`, a11y `關閉查字` / `Close dictionary`). Search field (magnifier, placeholder `searchPlaceholder`, no autocap/autocorrect, return key "search", system clear button). Results: debounced 80 ms (160 ms in low-power/reduced-motion or legacy iOS) → `filterWords(allWords, progress, query, 'all')` (§4.4), **first 36** results. States: empty query → big magnifier + placeholder text; no results → magnifier + `noLibraryWords`. Result row: primary word (bold) + group pill; pinyin line (English UI only); meaning detail (2 lines); example primary (1 line); chevron. Tap → dismiss sheet, then push word detail with `source=home`.

### 1.5 Study tab

Top: bank bar + filter button; filter panel (status/level/initial) under it when open (title `studyFilterTitle`, count = number of words matching the filters).

The study tab always shows **one session** (§3.6). States:

* **No cards** (`session.total == 0`): empty card, title `noChineseWords` (English UI) / `noStudyWords` (zh UI), text `relaxFilters`.
* **Session complete** (summary card, radius 24): party-popper icon (orange) in a soft tile; title `sessionCompleteTitle`; `sessionCompleteText(known, review)` (counts of distinct words by **last** answer); two stat cells `dailyProgress` = `"studied/target"` and `streak`; line `sessionGoalDone` if goal reached else `sessionGoalLeft(target − studied)`; buttons: primary `nextSession` (new session), secondary `reviewMissed(n)` (only if n > 0; new session made of exactly the missed ids), secondary `goQuiz` (switch to Quiz tab).
* **In session**:
  * Header row: `sessionLabel(done, total)` (left, = "card done+1 of total", clamped) and `todayGoalLine(studiedToday, dailyTarget)` (right); 6 pt progress bar `done/total` (track `#DCEEFF`, fill accent).
  * **Card deck** (fixed card height: if window height < 740 or width < 360 → `clamp(h×0.60, 404, 432)`, else `clamp(h×0.54, 430, 470)`; radius 24, padding 18, gap 14). A dimmed underlay of the **next** card sits behind (opacity 0.32→1, scale 0.955→1, y 14→0 as the top card is dragged out) to read as a deck.
  * Card top row: group pill (`Core n`, accent-soft, 12 pt) left; right: add-to-set button, favorite button.
  * **Front** (unrevealed): primary text (English word 40/48 bold, or Chinese concise meaning 30/38 bold in English UI; auto-shrink to 72%, max 2 lines); in English UI the pinyin line (accent, 15 semibold); in zh UI the pronunciation (17, secondary). Below, a tappable prompt box with `eye.fill` and `tapToReveal`. Tapping anywhere on the face reveals.
  * **Back** (revealed): primary + pinyin + secondary line (zh UI: `/pron/`; English UI: `"<english word> <pronunciation>"`), then a meaning block (top hairline): small label (zh UI: the word's part of speech, e.g. `vt / vi`; English UI: `englishCounterpart`), meaning (22 semibold, ≤3 lines, min 2-line height) = concise Chinese meaning (zh UI) or the English word (English UI); optional supplemental box: label `supplementalMeanings` + text (≤2 lines; §4.3 format); optional example box (tinted bg, radius 14): primary example (≤2 lines) + secondary translation (≤2 lines). Scanned words may have no example → box omitted.
  * **Swipe**: drag right = known, left = review. Thresholds (pt): commit if |dx| ≥ 58, or |dx| ≥ 28 with |vx| ≥ 360 pt/s; on release also commit if |dx| ≥ 54. Horizontal intent requires |dx| ≥ 10 before vertical 12 (otherwise the scroll view wins). While dragging: card tilts up to ±7° (full tilt at 127.6 pt), scales to 0.988 at threshold and 0.958 at exit, green (right) / red (left) edge glow fades in, a big ✓ (`#248A3D`) or ✕ (`#D70015`) cue with the hint text appears around the threshold (hint text split on `:` into two lines, or for CJK hints without spaces split after 2 characters: `右滑` / `已會`). Crossing the threshold fires a Light haptic and a 1% scale pulse; committing fires a Heavy haptic and the card flies out with the release velocity (min 950 pt/s) to `max(320, min(440, width−16))`, then the grade is applied. Below-threshold release springs back.
  * **Idle nudge hint**: 1.45 s after the first card appears, then 10 s after the last interaction, and repeating every 15 s, the card wiggles x: −9 (135 ms) → +11 (210 ms) → −6 (170 ms) → spring to 0. Disabled when conserving resources.
  * New card entry: 240 ms, y 4→0, scale 0.997→1 (skipped after a swipe hand-off).
  * **Bottom row**: square Undo button (54×54, `arrow.uturn.backward`, a11y `undo`, disabled unless undo is available §3.7); then, if not revealed, one blue button `showAnswer` (eye icon); if revealed, two buttons: `dontKnow` (red-soft bg `#FFF0EF`/dark `#3A1714`, red ✕ text `#D70015`/`#FF6961`) and `knowIt` (solid green `#34C759`, white ✓). Buttons grade exactly like swipes.
  * Favorite / add-to-set on the card follow §7.6 gating.
* Web keyboard shortcuts (Space/Enter reveal, ←/→ grade) — **web-only, drop**.

### 1.6 Quiz tab

Before a quiz (`!started`):
* Bank bar + filter button + panel (`quizFilterTitle`; count = quiz pool size).
* **Setup card** (unless just finished): `quizPracticeTitle` + segmented control `choiceQuizMode` / `speakingQuizMode`; divider; `questionCountTitle` with caption `"<questionBankPrefix> <poolSize> <questionBankUnit>"`; three chips `10/20/50 <questionUnit>`; a chip whose count exceeds the pool shows a second line `"<cappedQuestionPrefix> <poolSize>"`. Primary button `startQuiz` (target icon) or `startSpeaking` (language icon), disabled when the pool is empty. Changing practice type resets the quiz.
* **Results card** (after finishing): eyebrow `RESULT` / `SPEAKING` (literal English in both UIs); for choice mode a 112 pt score circle with `accuracy%` where `accuracy = round(correct / sessionTotal × 100)` (color tier ≥ 80 green, ≥ 50 orange, else red); title `quizFinished`/`speakingFinished`; `quizScore(correct, total)` / `speakingScore(total)`. Choice mode with misses: a list card `quizMissedTitle(n)` showing up to 8 rows "primary word — answer text" (`+N` if more), a primary button `practiceMissed(n)` (starts a study session made of exactly the missed ids and switches to Study), and a secondary `restartQuiz`. Otherwise one primary `restartQuiz`/`restartSpeaking`. Restart returns to setup (keeps settings).

During a quiz:
* Header: `"QUIZ n / total"` or `"SPEAKING n / total"` (literal) + a small capsule `✕ endQuiz` (ends immediately, back to setup, no results). Progress = `(index + answered?1:0) / total`. Bank bar and filters are hidden.
* **Choice question card**: caption `quizPrompt`; the prompt (English word 40 bold in zh UI; concise Chinese 30 bold + pinyin in English UI); 4 option rows (A/B/C/D letter badge + text, min height 56, radius 14). Answering locks the options (they stay identical even if progress changes): correct option turns green-soft with a ✓ badge, the chosen wrong option red-soft with ✕, others dim. Then a primary `nextQuestion` / `seeResults` (last question) button appears directly under the card, followed by a result card (green-soft `correctResult` or red-soft `wrongResult`) containing `answer` → answer text (zh UI: concise Chinese meaning; English UI: English word), optional `supplementalMeanings`, and if the word has an example: zh UI `englishExample`/`chineseTranslation`, English UI `chineseExample`/`englishExample` with the two example lines.
* **Speaking card** (§3.10): language icon + keyword (English word, or Chinese keyword + pinyin); inner box `speakingPromptLabel` → question, `speakingHintLabel` → support text. Two buttons until answered: primary `iSpoke` (records speakingCompleted) and secondary `showSampleAnswer` (records speakingSkipped). After either: next button, then a green-soft card `sampleAnswer` with `sampleAnswer` → reference answer and `sampleTranslation` → reference translation.
* Edge: started with a word that disappears → empty card `noQuizWords` + `relaxFilters`.

Quiz state resets (back to setup, counts cleared) when the active bank, quiz status/level/initial filter, study mode, or developer vocabulary changes. Question count chip changes do not reset.

### 1.7 Library tab

A single virtualized list (`List`/`LazyVStack`) whose header contains:
1. Bank bar.
2. **Header card**: title `libraryTitle` (auto-shrink) + capsule `filteredCount(n)`; search field (placeholder `searchPlaceholder`, magnifier turns accent when focused, clear button `clearSearch` when non-empty); when a query exists a caption `searchMeta(trimmedQuery, n)`; a row of 5 **status chips** (`all/favorites/review/mastered/new`, favorites locked for guests); the collapsible Level / First letter / Sort panel (§1.3).
3. **My Sets card**: icon + title `customSets` + caption `customSetsSummary(count)`; two small capsule buttons: `scanShort` (scan icon, or lock if guest) → scanner (gated), and `manage ›` (lock if guest) → `sets` (gated). Below: horizontal chips for the first 4 sets in current custom-set sort order (color dot, name, word count, lock if guest; tap → `sets`) or the text `noCustomSets`.

Rows (radius 14, padding 14, 10 pt spacing): left column — primary word (20 bold; English UI: Chinese concise 17), group pill (`Core n`, 12 semibold accent on accent-soft), part of speech (12 accent); pinyin (English UI); meaning detail (15 medium); example primary (13 secondary) if any. Right column — add-to-set button, favorite button, status text (`filterLabels.mastered/review/new` for the word's status). Tapping the row pushes word detail (`source=library`). Pressed state: slight lift/scale (0.987) + Medium haptic.

Search is debounced 80 ms (160 ms when conserving resources). Empty list: `noChineseWords` (English UI) / `noLibraryWords` + `relaxLibraryFilters(hasQuery)`.

Scrolling: scroll resets to top on tab change or any library filter/sort change. When > 24 results, a custom draggable fast-scroll thumb (36 pt) is shown on the right edge; after scrolling > 180 pt a floating capsule `↑ floatingTop` appears and animates back to top. (Native: use `.scrollIndicators` + `ScrollViewReader`; a draggable index/thumb is nice-to-have.)

Persisted library defaults: filter `all`, level `all`, initial `all`, **sort `alphabetical`** (§6.3 filter prefs).

### 1.8 Word detail (push `library/[wordId]`)

Back pill: `backHome` if opened from Home dictionary, else `backLibrary`. Content card:
* Eyebrow `detailTitle` (12 bold secondary); big word (SF Rounded 42 bold; English UI shows the concise Chinese meaning); pinyin (English UI); secondary line (`/pron/` or `"word /pron/"`).
* Trailing vertical stack: add-to-set button, favorite button (§7.6 gating). Add-to-set opens the set picker (§5.3) for this word.
* Badges row: `group`, `partOfSpeech`, status label.
* Section: label `chineseMeaning` (zh UI) / `englishCounterpart` (English UI) → meaning detail.
* Section `supplementalMeanings` → raw supplemental text (only if non-empty).
* Example card (only if the word has an example): zh UI `englishExample` → example, divider, `chineseTranslation` → exampleZh; English UI `chineseExample` → exampleZh, `englishExample` → example.

### 1.9 Profile tab ("我的" / "Me")

Order matters (tests assert analytics comes after the account section):
1. **Profile card** (centered): avatar circle with person icon; title = display name when permanently signed in (`full_name` → `name` → `given_name` from user metadata, whitespace-collapsed; else the email; an Apple private-relay email `@privaterelay.appleid.com` shows `appleAccountName`), otherwise `profileIdle`; text `profileProgress(dailyPercent, mastered)`; status capsule (green cloud, or red when account status is `error`) showing the current **account message** (§7.8; translated to English in English UI via the map in §1.12).
2. **Account card**: title `account`; trailing state `local` (Supabase not configured) / `signedIn` / `guest` / `signedOut`.
   * Not permanently signed in: if not configured, a notice box `accountUnavailableTitle` + `accountUnavailableText`; Google button (`googleSignIn`, subtitle `googleSignInHint`); Apple button (black/white, `appleSignIn`, subtitle `appleSignInHint`); caption `emailFallback`; email field (placeholder literal `Email`, email keyboard, no autocap); password field (`passwordPlaceholder`, secure); buttons `signIn` (primary) and `signUp` (outline). All disabled while busy or not configured.
   * Permanently signed in: red outline `signOut` button (disabled while busy).
3. **Learning analytics row** → push `stats`: chart icon, title `learningAnalytics`, subtitle `analyticsPreview(activeDays7, quizAccuracy)` (computed for the active bank).
4. **Learning experience card**: title `learningExperience`, caption `todayComplete(dailyPercent)`, book icon; three metric tiles: `dailyTarget` → `wordsUnit(dailyTarget)`; `favoriteWords` → favorites count (signed in) or lock + `favoritesRequireSignIn` (tile is a button: gated → sets Library filter to Favorites and switches to Library); `remainingSamples` → `stats.remaining`.
5. Tutorial row (`tutorial` / `replayTutorial`) — **web only, drop**.
6. **Settings row** → push `settings`: gear icon, `settings`, `settingsSummary`.

`dailyPercent = min(100, round(studiedToday / dailyTarget × 100))`.

### 1.10 Settings (push)

Back pill `backProfile`. Three cards:
1. **App settings** (`appSettings`, caption `displayTools`, gear icon):
   * Daily goal (`dailyTargetTitle` / `dailyTargetText`, target icon) with a 4-segment control `10 20 30 50` (a11y `dailyTargetOption(n)`). Writes `progress.dailyTarget` (clamped 5…100), which also sets study-session size.
   * Appearance (`appearance` / `appearanceText`, sun or moon icon) with segments `themeSystem / themeLight / themeDark`.
   * Lock Screen reminder toggle row (`streakReminder`, flame icon orange when on): subtitle `streakReminderOnText` / `streakReminderOffText`; trailing status light (switch semantics; use a SwiftUI `Toggle`). Default **on**.
2. **Privacy and support** (`legalSupport`, caption `legalSupportSummary`):
   * `privacyPolicy` / `privacyPolicyText` → opens `https://word7000-app.rio10255254.workers.dev/privacy.html` (external Safari).
   * `supportPage` / `supportPageText` → `…/support.html`.
   * Destructive row `deleteAccountData` / `deleteAccountDataText` (trash icon red), disabled while busy or when there is no user id (guest Supabase users DO have an id, so guests can delete too). Tap → alert `deleteAccountDataConfirmTitle` / `deleteAccountDataConfirmText` with `deleteAccountDataConfirmCancel` and destructive `deleteAccountDataConfirmAction` → §7.7.
3. **Developer data window** (`developerPanel`): status `developerEnabled`/`developerBuiltin`, intro `developerIntro`, stats `currentLibrary` = `<core vocab count> <rows>`, `dataStatus` = `localPreview`/`builtInVersion`, the stored preview summary, a message line, buttons `exportCsv`, `importData`, and `clearPreview` (enabled only when a preview exists). Export/import require a permanent account (`dataTools` gate). **On iOS the RN app cannot actually export or pick files**: export shows `exportCsvUnavailable`, import shows `importUnsupported`. Recommended native behavior: implement export via `ShareLink`/`UIActivityViewController` (`word7000-vocabulary-YYYY-MM-DD.csv`) and import via `.fileImporter` (`.csv`, `.json`) using §4.6; or hide the card. Clearing works today.

Initial developer message: `developerInitial`.

### 1.11 Personal analytics (push `stats`)

Uses **all words** (core + custom + scanned) and the full progress. Copy in §1.12 (`zhCopy` for zh UI, `enCopy` for English UI). Layout:
1. Back pill `back`.
2. Header: eyebrow `PERSONAL INSIGHTS` (accent, 11 bold), title (27 heavy), subtitle; chart icon tile.
3. Hero strip (three metrics): `weeklyActions` (`thisWeek`), current streak in orange (`currentStreak`), weekly change in green (`weeklyChange`, formatted `+12%`, `-5%`, or `–` when null).
4. **Learning trend** section with a `7 天 / 30 天` (`days(n)`) segmented control: a selected-day summary (long date `zh-TW`/`en-US` with weekday short, month short, day numeric; `selectedActions(n)`; a badge `goalProgress(goalActions, target)` green when met); a line+area chart (height 92, plot 76, accent line 2.5 pt, area gradient accent 30%→2%, three hairline gridlines, dashed green goal line at `min(max, target)`, dots on every point in 7-day mode, scrubbable by drag/tap with a Light haptic at most every 45 ms, selected point ring); x labels `M/D` (all in 7-day mode; every 5th + last + selected in 30-day mode); legend `dailyGoalLine`. `maxActions = max(1, dailyTarget, max(actions))`. Then a 2-column metric grid: active days (for the selected period), `dailyAverage` (30-day), `learningMinutes`, `learningSessions`, `goalDays`, `bestDay` (`M/D` or `–`).
5. **Learning results**: mastery rate %, mastered, review words, difficult words (= review count); a distribution bar mastered (green) / review (orange) / not studied (`separatorStrong`) with a legend.
6. **Learning methods**: rows study cards (`studyActions`), quiz answers with accuracy or `noAccuracy`, speaking completed with detail `speakingSkipped(n)`; subheading `modeMix` and a bar English-mode actions (accent) vs Chinese-mode actions (indigo).
7. **Streak and totals**: current streak, best streak, total recorded actions, today actions.
8. **Insight card**: `personalInsight` + `focus[analytics.focus]`.
9. Footnote `dataNote`.

All numbers per §3.11.

### 1.12 Verbatim UI copy

All strings below are copied verbatim from the source; functions are template strings. Keys are referenced throughout this document. Remember `english:` = zh-TW UI, `chinese:` = English UI.

#### 1.12.1 Tab labels and status filters

_Verbatim from `App.tsx` lines 441-447:_

```ts
const filters: Array<{ id: LibraryFilter; label: string }> = [
  { id: 'all', label: '全部' },
  { id: 'favorites', label: '收藏' },
  { id: 'review', label: '複習' },
  { id: 'mastered', label: '已會' },
  { id: 'new', label: '未背' },
];
```

_Verbatim from `App.tsx` lines 450-456:_

```ts
const tabs: Array<{ id: Tab; label: string; icon: typeof Home }> = [
  { id: 'home', label: '首頁', icon: Home },
  { id: 'study', label: '學習', icon: BookOpen },
  { id: 'quiz', label: '測驗', icon: Target },
  { id: 'library', label: '字庫', icon: Library },
  { id: 'profile', label: '我的', icon: User },
];
```

_Verbatim from `App.tsx` lines 4981-4994:_

```ts
export function tabLabelForMode(tab: Tab, studyMode: StudyMode): string {
  if (studyMode !== 'chinese') {
    return tabs.find((item) => item.id === tab)?.label ?? '';
  }

  const englishTabLabels: Record<Tab, string> = {
    home: 'Home',
    study: 'Chinese',
    quiz: 'Quiz',
    library: 'Library',
    profile: 'Me',
  };
  return englishTabLabels[tab];
}
```

Level chips: id `all` → `allLevels`; group ids → `group.replace('Core ', 'L')`. Initial chips: `all` → `allInitials`, `A`…`Z`.

#### 1.12.2 `modeCopy` (hero, search placeholders, filter titles, mode switch)

`brand`, `subtitle` and `heroEyebrow` are defined but not rendered anywhere — ignore. `overlayTitle`/`overlayText` are shown in the mode-switch overlay for the **target** mode.

_Verbatim from `App.tsx` lines 457-500:_

```ts
const modeCopy = {
  english: {
    brand: 'Word7000',
    subtitle: '每日輕學單字',
    toggleTitle: 'Switch to Chinese words',
    toggleText: 'Practice Chinese words with an English interface',
    overlayTitle: '英文單字模式',
    overlayText: '正在回到中文介面的英文單字 App',
    heroEyebrow: 'ENGLISH MODE',
    heroTitle: (target: number) => `今天 ${target} 個\n剛剛好`,
    heroDoneTitle: '今天的目標\n完成了',
    primaryAction: '開始今日學習',
    continueAction: '繼續學習',
    extraAction: '再學一組',
    libraryTitle: '完整字庫',
    searchPlaceholder: '搜尋英文、中文、例句或翻譯',
    studyFilterTitle: '學習篩選',
    quizFilterTitle: '測驗篩選',
    libraryFilterTitle: '分級 / 字首',
    initialTitle: '字首',
    questionBankUnit: '個英文單字',
  },
  chinese: {
    brand: 'Chinese7000',
    subtitle: 'Daily Chinese word practice',
    toggleTitle: '切到英文單字',
    toggleText: '回到中文介面的英文單字 App',
    overlayTitle: 'Chinese Word Mode',
    overlayText: 'Read Chinese first, then recall the English word',
    heroEyebrow: 'CHINESE MODE',
    heroTitle: (target: number) => `${target} Chinese words\nfor today`,
    heroDoneTitle: "Today's goal\nis done",
    primaryAction: "Start today's practice",
    continueAction: 'Keep going',
    extraAction: 'Practice one more set',
    libraryTitle: 'Chinese Word Library',
    searchPlaceholder: 'Search Chinese, English words, examples, or translations',
    studyFilterTitle: 'Study Filters',
    quizFilterTitle: 'Quiz Filters',
    libraryFilterTitle: 'Level / First Letter',
    initialTitle: 'First Letter',
    questionBankUnit: 'Chinese words',
  },
} as const;
```

#### 1.12.3 `modeInterfaceCopy` (most UI strings)

Keys defined but never rendered (legacy): `completed`, `accountSync`, `reviewDue`, `reviewListEmpty`, `reviewListCount`, `dictionarySearch`, `keyboardHint` (web keyboard hint), `darkMode`, `darkModeOnText`, `darkModeOffText`, `toggleDarkMode`, `previousWord`, `nextWord`, `reviewAgain`, `known`, `returnTop`, `viewDetails`, `openCustomSets`, `editSet`, `setDetailActions`, `clearActiveSet`, `activeSet`, `activeSetCount`. `tutorial`/`replayTutorial` are web-only. Everything else is used; keep the full catalog anyway.

_Verbatim from `App.tsx` lines 502-1025:_

```ts
const modeInterfaceCopy = {
  english: {
    completed: '完成',
    dailyProgress: '今日進度',
    accountSync: '帳號登入與同步',
    streak: '連續天數',
    mastered: '已掌握',
    reviewDue: '待複習',
    reviewList: '複習清單',
    reviewListEmpty: '目前沒有卡住的單字',
    reviewListCount: (count: number) => `${count} 個單字需要再看一次`,
    dictionaryLookup: '快速查字',
    todayPlan: (due: number, fresh: number) => `${due} 個待複習 · ${fresh} 個新字`,
    reviewDueToday: '今日待複習',
    quickQuiz: '小測驗',
    quickQuizText: '10 題選擇題，檢查最近學的字',
    streakDays: (days: number) => `${days} 天`,
    dictionarySearch: '查詢字庫',
    noStudyWords: '沒有符合的學習單字',
    noChineseWords: '沒有符合的中文單字',
    noQuizWords: '沒有符合的測驗題目',
    noLibraryWords: '沒有符合的單字',
    relaxFilters: '可以放寬狀態、分級或字首篩選。',
    relaxLibraryFilters: (hasQuery: boolean) => (hasQuery ? '可以清除搜尋，或換一個分級、字首。' : '可以換一個分級、字首。'),
    favoriteWord: '收藏這個單字',
    unfavoriteWord: '取消收藏這個單字',
    englishCounterpart: '英文對照',
    chineseMeaning: '中文意思',
    supplementalMeanings: '補充意思',
    reviewAgain: '再複習',
    known: '已會',
    previousWord: '上一個',
    nextWord: '下一個',
    swipeReviewHint: '左滑不會',
    swipeKnownHint: '右滑已會',
    tapToReveal: '想一下，再點卡片看答案',
    coreBankName: '7000 單字',
    builtInBank: '內建',
    scanBankTag: '掃描',
    bankLabel: '字庫',
    bankWordCount: (count: number) => `${count} 個`,
    bankPickerTitle: '選擇字庫',
    bankPickerHint: '學習、測驗和字庫都會改用這個字庫',
    scanNewSheet: '掃描單字表',
    scanShort: '掃描',
    closeSheet: '關閉',
    showAnswer: '顯示答案',
    dontKnow: '不熟',
    knowIt: '認識',
    undo: '復原上一張',
    sessionLabel: (done: number, total: number) => `第 ${Math.min(done + 1, total)} / ${total} 張`,
    todayGoalLine: (studied: number, target: number) => `今日 ${studied} / ${target}`,
    sessionCompleteTitle: '這一組完成了',
    sessionCompleteText: (known: number, review: number) => `認識 ${known} 個 · 還不熟 ${review} 個`,
    sessionGoalDone: '今天的目標已達成，繼續加油！',
    sessionGoalLeft: (left: number) => `距離今天的目標還差 ${left} 個字`,
    nextSession: '再來一組',
    reviewMissed: (count: number) => `再練不熟的 ${count} 個`,
    goQuiz: '用測驗檢查記憶',
    keyboardHint: '鍵盤：空白鍵看答案，← 不熟，→ 認識',
    filterButtonLabel: '篩選',
    filterStatus: '狀態',
    filterLevel: '分級',
    filterSort: '排序',
    filterCountUnit: '個',
    filterLabels: {
      all: '全部',
      favorites: '收藏',
      review: '複習',
      mastered: '已會',
      new: '未背',
    },
    sortDefault: '原本順序',
    sortAlphabetical: '英文字首 A-Z',
    allLevels: '全部分級',
    allInitials: '全部',
    levelAccessibility: (label: string) => `分級 ${label}`,
    initialAccessibility: (label: string) => (label === 'all' ? '字首 全部' : `字首 ${label}`),
    sortAccessibility: (label: string) => `排序 ${label}`,
    questionCountTitle: '選擇題數',
    questionBankPrefix: '目前題庫',
    questionUnit: '題',
    cappedQuestionPrefix: '出',
    quizPracticeTitle: '練習方式',
    choiceQuizMode: '選擇題',
    speakingQuizMode: '口說練習',
    startQuiz: '開始測驗',
    startSpeaking: '開始口說練習',
    quizFinished: '測驗完成',
    speakingFinished: '口說練習完成',
    quizScore: (correct: number, total: number) => `答對 ${correct} / ${total} 題`,
    speakingScore: (total: number) => `完成 ${total} 張口說卡`,
    restartQuiz: '重新選題',
    restartSpeaking: '重新練習',
    correctResult: '答對了',
    wrongResult: '先放進複習',
    speakingPromptLabel: '口說題目',
    speakingHintLabel: '回答提示',
    iSpoke: '我說完了',
    showSampleAnswer: '看參考回答',
    sampleAnswer: '參考回答',
    sampleTranslation: '中文翻譯',
    englishExample: '英文例句',
    chineseExample: '中文例句',
    chineseTranslation: '中文翻譯',
    answer: '答案',
    nextQuestion: '下一題',
    seeResults: '看結果',
    endQuiz: '結束',
    quizPrompt: '選出正確的中文意思',
    quizMissedTitle: (count: number) => `答錯的 ${count} 個字`,
    practiceMissed: (count: number) => `用學習卡複習這 ${count} 個字`,
    returnTop: '回到頂端',
    floatingTop: '回頂端',
    clearSearch: '清除搜尋',
    searchMeta: (query: string, count: number) => `搜尋「${query}」：找到 ${count} 個結果`,
    filteredCount: (count: number) => `篩選後 ${count} 個`,
    resultCount: (count: number, start: number, end: number) => `共 ${count} 個結果，顯示第 ${count === 0 ? 0 : start + 1}-${end} 個`,
    viewDetails: '完整資訊',
    viewWordDetails: (word: string) => `查看 ${word} 完整資訊`,
    favoriteWordName: (word: string) => `收藏 ${word}`,
    unfavoriteWordName: (word: string) => `取消收藏 ${word}`,
    backLibrary: '返回字庫',
    backHome: '返回首頁',
    detailTitle: '完整資訊',
    profileIdle: '穩定累積中',
    profileProgress: (percent: number, mastered: number) => `今天完成 ${percent}%，目前掌握 ${mastered} 個單字。`,
    account: '帳號',
    appleAccountName: 'Apple 使用者',
    learningAnalytics: '學習分析',
    analyticsPreview: (activeDays: number, accuracy: number | null) =>
      `近 7 天活躍 ${activeDays} 天 · 測驗正確率 ${accuracy === null ? '尚無資料' : `${accuracy}%`}`,
    guest: '訪客',
    signedIn: '已登入',
    signedOut: '未登入',
    local: '本機',
    accountUnavailableTitle: '帳號同步暫未開放',
    accountUnavailableText: '目前會先把進度保存在這台裝置。雲端同步開放後，就能登入帳號跨裝置保存。',
    passwordPlaceholder: '密碼',
    googleSignIn: '使用 Google 快速登入',
    googleSignInHint: '同步收藏、複習和連續天數',
    appleSignIn: '使用 Apple 登入',
    appleSignInHint: '適合在 iPhone 上快速同步',
    emailFallback: 'Email 備用登入',
    signIn: '登入',
    signUp: '註冊',
    signOut: '登出',
    learningExperience: '學習體驗',
    todayComplete: (percent: number) => `今天完成 ${percent}%`,
    dailyTarget: '每日目標',
    favoriteWords: '收藏單字',
    favoritesRequireSignIn: '需登入',
    remainingSamples: '尚未學過',
    tutorial: '教學',
    replayTutorial: '重新查看加入主畫面教學',
    settings: '設定',
    settingsSummary: '深色模式、連勝提醒與資料工具',
    openSettings: '開啟設定',
    backProfile: '返回我的',
    appSettings: 'App 設定',
    displayTools: '顯示模式、連勝提醒與本機工具',
    legalSupport: '隱私與支援',
    legalSupportSummary: '隱私、支援與帳號資料管理',
    privacyPolicy: '隱私權政策',
    privacyPolicyText: '查看 Word7000 如何保存與同步學習資料',
    supportPage: '支援頁面',
    supportPageText: '登入、同步、更新與帳號資料說明',
    deleteAccountData: '刪除帳號與資料',
    deleteAccountDataText: '永久刪除這個 Word7000 身分、學習進度、活躍紀錄與提醒資料',
    deleteAccountDataConfirmTitle: '刪除帳號與所有資料？',
    deleteAccountDataConfirmText: '這會永久刪除目前的 Word7000 身分、學習進度、單字集、每日活躍紀錄與鎖定畫面提醒，且無法復原。',
    deleteAccountDataConfirmCancel: '取消',
    deleteAccountDataConfirmAction: '確認刪除',
    darkMode: '深色模式',
    appearance: '外觀',
    appearanceText: '跟隨系統，或固定使用淺色、深色',
    themeSystem: '跟隨系統',
    themeLight: '淺色',
    themeDark: '深色',
    dailyTargetTitle: '每日目標',
    dailyTargetText: '每天想學幾個單字，也決定每組學習卡的張數',
    dailyTargetOption: (count: number) => `每日 ${count} 個單字`,
    wordsUnit: (count: number) => `${count} 個`,
    darkModeOnText: '已切換成夜間閱讀介面',
    darkModeOffText: '切換成夜間閱讀介面',
    toggleDarkMode: '切換深色模式',
    streakReminder: '鎖定畫面學習提醒',
    streakReminderOnText: '每天中午提醒，連勝最後一小時倒數',
    streakReminderOffText: '不顯示鎖定畫面與靈動島提醒',
    toggleStreakReminder: '切換鎖定畫面學習提醒',
    on: '開啟',
    off: '關閉',
    developerPanel: '開發人員資料窗口',
    developerEnabled: '本機預覽啟用中',
    developerBuiltin: '目前使用內建字庫',
    developerIntro: '匯出目前字庫後，可以在外部修改例句與翻譯；匯入後會先套用在這台裝置，方便檢查正式更新前的效果。',
    currentLibrary: '目前字庫',
    rows: '筆',
    dataStatus: '資料狀態',
    localPreview: '本機預覽',
    builtInVersion: '內建版本',
    exportCsv: '匯出 CSV',
    importData: '匯入資料',
    clearPreview: '清除本機預覽',
    customSets: '我的單字集',
    customSetsSummary: (count: number) => `${count} 個自訂資料夾，可用於學習與測驗`,
    manage: '管理',
    openCustomSets: '管理單字集',
    backCustomSets: '返回我的',
    backToSets: '返回單字集',
    setLibrary: '自訂單字集',
    setLibrarySummary: '把常用、考試或主題單字分開整理',
    editSet: '編輯單字集',
    openSetSettings: '開啟單字集設定',
    setDetailActions: '操作',
    editSetName: '單字集名稱',
    saveSetName: '儲存名稱',
    deleteSet: '刪除單字集',
    wordsInSet: '資料夾單字',
    emptySetWords: '這個資料夾還沒有單字。',
    removeFromSet: '移除',
    setRenamed: (name: string) => `已更新「${name}」`,
    setDeleted: (name: string) => `已刪除「${name}」`,
    removedFromSet: (word: string, setName: string) => `已從「${setName}」移除 ${word}`,
    customSetSortRecent: '最近更新',
    customSetSortName: '名稱 A-Z',
    customSetSortManual: '建立順序',
    createSet: '新增資料夾',
    newSetPlaceholder: '例如：旅行英文、托福片語',
    addToSet: '加入單字集',
    addToSetName: (word: string) => `把 ${word} 加入單字集`,
    setPickerTitle: (word: string) => `加入「${word}」`,
    setPickerEmpty: '還沒有單字集，先新增一個資料夾。',
    createAndAdd: '新增並加入',
    addExistingWord: '加入',
    addedToSet: (word: string, setName: string) => `已把 ${word} 加入「${setName}」`,
    noCustomSets: '尚未建立單字集',
    customSetCount: (count: number) => `${count} 個單字`,
    chooseCustomSet: '選擇要加入的單字集',
    manualWordTitle: '手動新增單字',
    manualWordIntro: '可以加入字庫沒有的單字，也可以用 CSV 一次匯入。',
    customWordWordPlaceholder: '英文單字',
    customWordMeaningPlaceholder: '中文意思',
    customWordSupplementalMeaningPlaceholder: '補充意思，可空白',
    customWordPronunciationPlaceholder: '音標，可空白',
    customWordPartPlaceholder: '詞性，可空白',
    customWordExamplePlaceholder: '英文例句，可空白',
    customWordExampleZhPlaceholder: '中文例句，可空白',
    addManualWord: '新增到單字集',
    importCustomCsv: '匯入自訂 CSV',
    customSetMessageDefault: '單字集會依照目前登入帳號分開記憶在這台裝置。',
    customSetSelectPlaceholder: '先選一個單字集',
    startSetStudy: '用這組學習',
    startSetQuiz: '用這組測驗',
    activeSet: (name: string) => `目前使用「${name}」`,
    clearActiveSet: '清除',
    activeSetCount: (count: number) => `${count} 個單字`,
    setCreated: (name: string) => `已建立「${name}」`,
    customWordAdded: (word: string, setName: string) => `已新增 ${word} 到「${setName}」`,
    customImportApplied: (added: number, skipped: number) => `已匯入 ${added} 個新單字，略過 ${skipped} 筆。`,
    scanSaved: (count: number, name: string) => `已把 ${count} 個掃描單字存進「${name}」`,
  },
  chinese: {
    completed: 'Complete',
    dailyProgress: 'Today',
    accountSync: 'Account and sync',
    streak: 'Streak',
    mastered: 'Mastered',
    reviewDue: 'Review',
    reviewList: 'Review List',
    reviewListEmpty: 'No words need review right now',
    reviewListCount: (count: number) => `${count} words need another look`,
    dictionaryLookup: 'Quick Dictionary',
    todayPlan: (due: number, fresh: number) => `${due} to review · ${fresh} new`,
    reviewDueToday: 'Due Today',
    quickQuiz: 'Quick Quiz',
    quickQuizText: 'A short multiple-choice check on recent words',
    streakDays: (days: number) => `${days} ${days === 1 ? 'day' : 'days'}`,
    dictionarySearch: 'Search the library',
    noStudyWords: 'No matching study words',
    noChineseWords: 'No matching Chinese words',
    noQuizWords: 'No matching quiz questions',
    noLibraryWords: 'No matching words',
    relaxFilters: 'Try loosening the status, level, or first-letter filters.',
    relaxLibraryFilters: (hasQuery: boolean) => (hasQuery ? 'Clear search or try another level or first letter.' : 'Try another level or first letter.'),
    favoriteWord: 'Save this word',
    unfavoriteWord: 'Remove this word from saved',
    englishCounterpart: 'English Match',
    chineseMeaning: 'Chinese Meaning',
    supplementalMeanings: 'Extra Meanings',
    reviewAgain: 'Review Again',
    known: 'I Know It',
    previousWord: 'Previous',
    nextWord: 'Next',
    swipeReviewHint: 'Swipe left: still learning',
    swipeKnownHint: 'Swipe right: I know it',
    tapToReveal: 'Think first, then tap to check',
    coreBankName: '7000 Words',
    builtInBank: 'Built-in',
    scanBankTag: 'Scanned',
    bankLabel: 'Bank',
    bankWordCount: (count: number) => `${count} words`,
    bankPickerTitle: 'Choose a Word Bank',
    bankPickerHint: 'Study, quiz, and library all switch to this bank',
    scanNewSheet: 'Scan a Word Sheet',
    scanShort: 'Scan',
    closeSheet: 'Close',
    showAnswer: 'Show Answer',
    dontKnow: 'Not Yet',
    knowIt: 'I Know It',
    undo: 'Undo last card',
    sessionLabel: (done: number, total: number) => `Card ${Math.min(done + 1, total)} of ${total}`,
    todayGoalLine: (studied: number, target: number) => `Today ${studied} / ${target}`,
    sessionCompleteTitle: 'Set complete',
    sessionCompleteText: (known: number, review: number) => `${known} known · ${review} still learning`,
    sessionGoalDone: "Today's goal is done. Nice work!",
    sessionGoalLeft: (left: number) => `${left} more words to reach today's goal`,
    nextSession: 'Next Set',
    reviewMissed: (count: number) => `Practice ${count} missed words`,
    goQuiz: 'Check with a quiz',
    keyboardHint: 'Keyboard: Space to reveal, ← still learning, → know it',
    filterButtonLabel: 'Filters',
    filterStatus: 'Status',
    filterLevel: 'Level',
    filterSort: 'Sort',
    filterCountUnit: 'items',
    filterLabels: {
      all: 'All',
      favorites: 'Saved',
      review: 'Review',
      mastered: 'Known',
      new: 'New',
    },
    sortDefault: 'Original Order',
    sortAlphabetical: 'English A-Z',
    allLevels: 'All Levels',
    allInitials: 'All',
    levelAccessibility: (label: string) => `Level ${label}`,
    initialAccessibility: (label: string) => (label === 'all' ? 'First letter All' : `First letter ${label}`),
    sortAccessibility: (label: string) => `Sort ${label}`,
    questionCountTitle: 'Choose Question Count',
    questionBankPrefix: 'Question bank',
    questionUnit: 'questions',
    cappedQuestionPrefix: 'Uses',
    quizPracticeTitle: 'Practice Type',
    choiceQuizMode: 'Multiple Choice',
    speakingQuizMode: 'Speaking Cards',
    startQuiz: 'Start Quiz',
    startSpeaking: 'Start Speaking',
    quizFinished: 'Quiz Complete',
    speakingFinished: 'Speaking Complete',
    quizScore: (correct: number, total: number) => `${correct} / ${total} correct`,
    speakingScore: (total: number) => `${total} speaking cards completed`,
    restartQuiz: 'Choose Again',
    restartSpeaking: 'Practice Again',
    correctResult: 'Correct',
    wrongResult: 'Added to Review',
    speakingPromptLabel: 'Speaking Prompt',
    speakingHintLabel: 'Answer Hint',
    iSpoke: 'I Finished Speaking',
    showSampleAnswer: 'Show Sample Answer',
    sampleAnswer: 'Sample Answer',
    sampleTranslation: 'English Translation',
    englishExample: 'English Example',
    chineseExample: 'Chinese Example',
    chineseTranslation: 'Chinese Translation',
    answer: 'Answer',
    nextQuestion: 'Next',
    seeResults: 'See Results',
    endQuiz: 'End',
    quizPrompt: 'Pick the matching English word',
    quizMissedTitle: (count: number) => `${count} missed words`,
    practiceMissed: (count: number) => `Practice these ${count} words`,
    returnTop: 'Back to Top',
    floatingTop: 'Top',
    clearSearch: 'Clear search',
    searchMeta: (query: string, count: number) => `Search "${query}": ${count} results`,
    filteredCount: (count: number) => `${count} words`,
    resultCount: (count: number, start: number, end: number) => `${count} results, showing ${count === 0 ? 0 : start + 1}-${end}`,
    viewDetails: 'Details',
    viewWordDetails: (word: string) => `View details for ${word}`,
    favoriteWordName: (word: string) => `Save ${word}`,
    unfavoriteWordName: (word: string) => `Remove ${word} from saved`,
    backLibrary: 'Back to Library',
    backHome: 'Back to Home',
    detailTitle: 'Details',
    profileIdle: 'Building momentum',
    profileProgress: (percent: number, mastered: number) => `${percent}% complete today, ${mastered} words mastered.`,
    account: 'Account',
    appleAccountName: 'Apple user',
    learningAnalytics: 'Learning Analytics',
    analyticsPreview: (activeDays: number, accuracy: number | null) =>
      `${activeDays} active days this week · Quiz accuracy ${accuracy === null ? 'No data yet' : `${accuracy}%`}`,
    guest: 'Guest',
    signedIn: 'Signed in',
    signedOut: 'Signed out',
    local: 'Local',
    accountUnavailableTitle: 'Account sync is not available yet',
    accountUnavailableText: 'Progress is saved on this device for now. When cloud sync is available, you can sign in to keep it across devices.',
    passwordPlaceholder: 'Password',
    googleSignIn: 'Continue with Google',
    googleSignInHint: 'Sync saved words, review, and streaks',
    appleSignIn: 'Continue with Apple',
    appleSignInHint: 'Fast sign-in on iPhone',
    emailFallback: 'Email fallback',
    signIn: 'Sign In',
    signUp: 'Sign Up',
    signOut: 'Sign Out',
    learningExperience: 'Learning Experience',
    todayComplete: (percent: number) => `${percent}% complete today`,
    dailyTarget: 'Daily Target',
    favoriteWords: 'Saved Words',
    favoritesRequireSignIn: 'Sign in',
    remainingSamples: 'Not Started',
    tutorial: 'Tutorial',
    replayTutorial: 'Review home-screen tutorial',
    settings: 'Settings',
    settingsSummary: 'Dark mode, streak alerts, and data tools',
    openSettings: 'Open settings',
    backProfile: 'Back to Me',
    appSettings: 'App Settings',
    displayTools: 'Display, streak alerts, and local tools',
    legalSupport: 'Privacy and Support',
    legalSupportSummary: 'Privacy, support, and account data controls',
    privacyPolicy: 'Privacy Policy',
    privacyPolicyText: 'See how Word7000 stores and syncs learning data',
    supportPage: 'Support Page',
    supportPageText: 'Help with sign-in, sync, updates, and account data',
    deleteAccountData: 'Delete Account and Data',
    deleteAccountDataText: 'Permanently delete this Word7000 identity, progress, activity, and reminder data',
    deleteAccountDataConfirmTitle: 'Delete account and all data?',
    deleteAccountDataConfirmText: 'This permanently deletes the current Word7000 identity, learning progress, custom sets, daily activity, and Lock Screen reminders. This cannot be undone.',
    deleteAccountDataConfirmCancel: 'Cancel',
    deleteAccountDataConfirmAction: 'Delete Data',
    darkMode: 'Dark Mode',
    appearance: 'Appearance',
    appearanceText: 'Follow the system, or always use light or dark',
    themeSystem: 'System',
    themeLight: 'Light',
    themeDark: 'Dark',
    dailyTargetTitle: 'Daily Goal',
    dailyTargetText: 'How many words a day, and how many cards per study set',
    dailyTargetOption: (count: number) => `${count} words a day`,
    wordsUnit: (count: number) => `${count} words`,
    darkModeOnText: 'Night reading interface is on',
    darkModeOffText: 'Switch to the night reading interface',
    toggleDarkMode: 'Toggle dark mode',
    streakReminder: 'Lock Screen Study Reminder',
    streakReminderOnText: 'Remind me at noon and during the final streak hour',
    streakReminderOffText: 'Hide Lock Screen and Dynamic Island reminders',
    toggleStreakReminder: 'Toggle Lock Screen study reminders',
    on: 'On',
    off: 'Off',
    developerPanel: 'Developer Data Window',
    developerEnabled: 'Local preview enabled',
    developerBuiltin: 'Using built-in library',
    developerIntro: 'Export the current library, edit examples and translations externally, then import it for a local preview before a formal update.',
    currentLibrary: 'Current Library',
    rows: 'rows',
    dataStatus: 'Data Status',
    localPreview: 'Local Preview',
    builtInVersion: 'Built-in',
    exportCsv: 'Export CSV',
    importData: 'Import Data',
    clearPreview: 'Clear Local Preview',
    customSets: 'My Sets',
    customSetsSummary: (count: number) => `${count} custom folders for study and quiz`,
    manage: 'Manage',
    openCustomSets: 'Manage sets',
    backCustomSets: 'Back to Me',
    backToSets: 'Back to Sets',
    setLibrary: 'Custom Sets',
    setLibrarySummary: 'Group words by topic, exam, or personal lists',
    editSet: 'Edit Set',
    openSetSettings: 'Open set settings',
    setDetailActions: 'Actions',
    editSetName: 'Set name',
    saveSetName: 'Save Name',
    deleteSet: 'Delete Set',
    wordsInSet: 'Words in Set',
    emptySetWords: 'This folder has no words yet.',
    removeFromSet: 'Remove',
    setRenamed: (name: string) => `Updated "${name}"`,
    setDeleted: (name: string) => `Deleted "${name}"`,
    removedFromSet: (word: string, setName: string) => `Removed ${word} from "${setName}"`,
    customSetSortRecent: 'Recently Updated',
    customSetSortName: 'Name A-Z',
    customSetSortManual: 'Created Order',
    createSet: 'New Folder',
    newSetPlaceholder: 'Travel Chinese, HSK verbs...',
    addToSet: 'Add to set',
    addToSetName: (word: string) => `Add ${word} to a set`,
    setPickerTitle: (word: string) => `Add "${word}"`,
    setPickerEmpty: 'No sets yet. Create a folder first.',
    createAndAdd: 'Create and Add',
    addExistingWord: 'Add',
    addedToSet: (word: string, setName: string) => `Added ${word} to "${setName}"`,
    noCustomSets: 'No custom sets yet',
    customSetCount: (count: number) => `${count} words`,
    chooseCustomSet: 'Choose a set',
    manualWordTitle: 'Add a Word',
    manualWordIntro: 'Add words missing from the library, or import a CSV file.',
    customWordWordPlaceholder: 'Word',
    customWordMeaningPlaceholder: 'Main meaning',
    customWordSupplementalMeaningPlaceholder: 'Extra meanings, optional',
    customWordPronunciationPlaceholder: 'Pronunciation, optional',
    customWordPartPlaceholder: 'Part of speech, optional',
    customWordExamplePlaceholder: 'Example, optional',
    customWordExampleZhPlaceholder: 'Translation, optional',
    addManualWord: 'Add to Set',
    importCustomCsv: 'Import Custom CSV',
    customSetMessageDefault: 'Sets are remembered separately for the current signed-in account on this device.',
    customSetSelectPlaceholder: 'Choose a set first',
    startSetStudy: 'Study This Set',
    startSetQuiz: 'Quiz This Set',
    activeSet: (name: string) => `Using "${name}"`,
    clearActiveSet: 'Clear',
    activeSetCount: (count: number) => `${count} words`,
    setCreated: (name: string) => `Created "${name}"`,
    customWordAdded: (word: string, setName: string) => `Added ${word} to "${setName}"`,
    customImportApplied: (added: number, skipped: number) => `Imported ${added} new words, skipped ${skipped}.`,
    scanSaved: (count: number, name: string) => `Saved ${count} scanned words to "${name}"`,
  },
} as const;
```

#### 1.12.4 Account-upgrade sheet copy (per gate reason)

_Verbatim from `App.tsx` lines 1027-1072:_

```ts
const accountUpgradeCopy = {
  english: {
    badge: {
      customSets: '單字集會同步到你的帳號',
      dataTools: '資料工具只會連結你的帳號',
      favorites: '收藏會同步到你的帳號',
      protectProgress: '目前進度已保留',
    },
    body: {
      customSets: '登入後即可建立與管理單字集，並在換機後完整取回。',
      dataTools: '登入後才會開放匯入、匯出與帳號資料工具。',
      favorites: '收藏會安全同步到你的帳號，換機或重新安裝後仍能找回。',
      protectProgress: '登入後可跨裝置保留連續天數、收藏、複習狀態與學習紀錄。',
    },
    later: '稍後再說',
    privacy: '不登入也能繼續查字、學習與測驗。',
    title: {
      customSets: '登入以使用單字集',
      dataTools: '登入以使用資料工具',
      favorites: '登入後才能收藏',
      protectProgress: '保護你的學習進度',
    },
  },
  chinese: {
    badge: {
      customSets: 'Sets sync with your account',
      dataTools: 'Data tools stay linked to your account',
      favorites: 'Saved words sync with your account',
      protectProgress: 'Your current progress is safe',
    },
    body: {
      customSets: 'Sign in to create and manage custom sets and restore them on another device.',
      dataTools: 'Sign in to use imports, exports, and account data tools.',
      favorites: 'Saved words stay with your account, even after changing devices or reinstalling the app.',
      protectProgress: 'Sign in to keep your streak, saved words, review status, and learning history across devices.',
    },
    later: 'Not Now',
    privacy: 'You can keep using dictionary, study, and quiz without signing in.',
    title: {
      customSets: 'Sign In for Custom Sets',
      dataTools: 'Sign In for Data Tools',
      favorites: 'Sign In to Save Words',
      protectProgress: 'Protect Your Progress',
    },
  },
} as const;
```

#### 1.12.5 System copy (developer panel, update overlay/check, install guide)

_Verbatim from `App.tsx` lines 1074-1143:_

```ts
const systemCopy = {
  english: {
    developerInitial: '可匯出 CSV 修改例句，再匯入成這台裝置的預覽字庫。',
    exportCsvSuccess: (count: number) => `已匯出 ${count} 筆字庫 CSV。`,
    exportCsvUnavailable: '目前這個裝置不支援直接下載 CSV。',
    importReading: '正在讀取匯入檔案...',
    importUnsupported: '目前只有網頁版支援從檔案匯入字庫。',
    importNoFile: '沒有選擇檔案。',
    importReadFailed: '讀取檔案失敗，請確認檔案可以正常開啟。',
    importApplied: (updated: number, added: number, total: number) => `已套用本機預覽：更新 ${updated} 筆，新增 ${added} 筆，目前共 ${total} 筆。`,
    importAppliedWithErrors: (summary: string, count: number) => `${summary} 另有 ${count} 筆未套用。`,
    clearPreview: '已清除本機預覽，現在使用內建 7000 字庫。',
    updateTitle: '需要更新才能繼續使用',
    updateDetail: '為了避免字庫、帳號同步或介面版本不同步，系統會自動更新到最新版。',
    updateCountdown: (seconds: number) => `${seconds} 秒後自動更新`,
    updateNow: '立即更新',
    updateCheckTitle: '檢查 App 更新',
    updateCheckDetail: '自動更新已開啟，也可以隨時手動檢查。',
    updateChecking: '正在檢查',
    updateAvailable: '新版已就緒',
    updateAvailableDetail: '新版已下載完成，點一下立即套用。',
    updateCurrent: '已是最新版本',
    updateCurrentDetail: '目前版本已同步，自動更新仍會持續運作。',
    updateRetry: '重新檢查',
    updateCheckFailed: '暫時無法連線，請稍後再試。',
    testFlightUpdateButton: '開啟 TestFlight',
    testFlightUpdateDetail: '這個版本已停止使用，請到 TestFlight 安裝最新版後再繼續。',
    testFlightUpdateHint: '安裝完成後重新開啟 Word7000',
    installGuide: {
      closeAccessibility: '關閉加入主畫面教學',
      dismiss: '我先自己操作',
      done: '完成',
      next: '下一步',
    },
  },
  chinese: {
    developerInitial: 'Export the CSV, edit examples externally, then import it as a local preview on this device.',
    exportCsvSuccess: (count: number) => `Exported ${count} vocabulary rows as CSV.`,
    exportCsvUnavailable: 'This device does not support direct CSV downloads yet.',
    importReading: 'Reading the import file...',
    importUnsupported: 'File import is currently supported only on the web version.',
    importNoFile: 'No file was selected.',
    importReadFailed: 'Could not read the file. Please make sure it opens correctly.',
    importApplied: (updated: number, added: number, total: number) => `Local preview applied: ${updated} updated, ${added} added, ${total} rows total.`,
    importAppliedWithErrors: (summary: string, count: number) => `${summary} ${count} rows were not applied.`,
    clearPreview: 'Local preview cleared. The built-in 7000-word library is active again.',
    updateTitle: 'Update required',
    updateDetail: 'To keep the word library, account sync, and interface version aligned, the app will update automatically.',
    updateCountdown: (seconds: number) => `Auto-updating in ${seconds}s`,
    updateNow: 'Update now',
    updateCheckTitle: 'Check for App Updates',
    updateCheckDetail: 'Automatic updates are on, and you can check at any time.',
    updateChecking: 'Checking',
    updateAvailable: 'Update ready',
    updateAvailableDetail: 'The latest update is downloaded and ready to apply.',
    updateCurrent: 'Up to date',
    updateCurrentDetail: 'This version is current and automatic updates remain active.',
    updateRetry: 'Check again',
    updateCheckFailed: 'Unable to connect right now. Please try again shortly.',
    testFlightUpdateButton: 'Open TestFlight',
    testFlightUpdateDetail: 'This build is no longer supported. Install the latest version from TestFlight to continue.',
    testFlightUpdateHint: 'Reopen Word7000 after installing the update',
    installGuide: {
      closeAccessibility: 'Close home-screen tutorial',
      dismiss: "I'll do this myself",
      done: 'Done',
      next: 'Next',
    },
  },
} as const;
```

#### 1.12.6 Account status messages (`account.message`) and their English-UI translations

The data layer writes Chinese status messages; in English UI they are displayed through this map (unmapped messages, e.g. raw Supabase error text, are shown as-is). Messages actually produced by the code: `本機記憶中`, `正在準備訪客進度`, `檢查登入狀態`, `訪客進度保存在這台裝置`, `訪客進度已自動保存`, `已登入，正在背景同步` (**not in the map → shown in Chinese even in English UI; add `Signed in, syncing in the background`**), `已登入並同步`, `已建立新的帳號記憶`, `進度已保存在本機，稍後會自動重試同步` (**not mapped; add `Progress saved on this device; sync will retry automatically`**), `帳號服務目前無法使用` (**not mapped; add `Account service is unavailable`**), `正在開啟 Google 登入`, `請完成 Google 登入`, `無法開啟手機登入流程`, `已取消登入`, `Google 帳號連結失敗` / `Google 帳號連結未完成` (not mapped), `正在開啟 Apple 登入`, `此裝置目前無法使用 Apple 登入`, `Apple 登入沒有回傳帳號憑證`, `Apple 登入沒有回傳授權碼` (not mapped), `Apple 帳號授權狀態無效，請重新登入` (not mapped), `Apple 登入失敗`, `登入導回失敗`, `登入導回沒有取得帳號資料`, `Email 和密碼至少 6 碼`, `建立帳號中`, `請確認信箱後登入`, `請輸入 Email 和密碼`, `登入中`, `登入失敗`, `正在切換為訪客模式`, `已登出，訪客進度保存在這台裝置`, `請先登入`, `正在刪除帳號與資料`, `帳號已刪除，正在建立訪客進度`, `帳號已刪除，訪客進度保存在這台裝置`, `無法開啟連結`, `登入狀態檢查失敗` (not mapped).

_Verbatim from `App.tsx` lines 10275-10321:_

```ts
function accountMessageForMode(message: string, studyMode: StudyMode): string {
  if (studyMode !== 'chinese') {
    return message;
  }

  const messages: Record<string, string> = {
    本機記憶中: 'Saved locally',
    正在準備訪客進度: 'Preparing guest progress',
    訪客進度已自動保存: 'Guest progress saved automatically',
    訪客進度保存在這台裝置: 'Guest progress is saved on this device',
    已登入並同步: 'Signed in and synced',
    檢查登入狀態: 'Checking sign-in',
    未登入: 'Signed out',
    同步中: 'Syncing',
    已保存到帳號: 'Saved to account',
    已登入: 'Signed in',
    已建立新的帳號記憶: 'Created fresh account memory',
    '正在開啟 Google 登入': 'Opening Google sign-in',
    '請完成 Google 登入': 'Complete Google sign-in',
    '無法開啟手機登入流程': 'Could not open mobile sign-in',
    已取消登入: 'Sign-in canceled',
    '正在開啟 Apple 登入': 'Opening Apple sign-in',
    'Apple 登入在網頁預覽中只顯示入口': 'Apple sign-in is shown here for iPhone preview',
    'Apple 登入只能在 iPhone App 使用': 'Apple sign-in is only available in the iPhone app',
    '此裝置目前無法使用 Apple 登入': 'Apple sign-in is not available on this device',
    'Apple 登入沒有回傳帳號憑證': 'Apple sign-in did not return account credentials',
    'Apple 登入失敗': 'Apple sign-in failed',
    登入導回失敗: 'Sign-in redirect failed',
    登入導回沒有取得帳號資料: 'The sign-in redirect did not return account data',
    請先登入: 'Please sign in first',
    正在刪除帳號與資料: 'Deleting account and data',
    帳號學習資料已刪除: 'Account learning data deleted',
    無法開啟連結: 'Could not open link',
    建立帳號中: 'Creating account',
    請確認信箱後登入: 'Check your email, then sign in',
    'Email 和密碼至少 6 碼': 'Email and password need at least 6 characters',
    '請輸入 Email 和密碼': 'Enter email and password',
    登入中: 'Signing in',
    登入失敗: 'Sign-in failed',
    已登出: 'Signed out',
    正在切換為訪客模式: 'Switching to guest mode',
    '已登出，訪客進度保存在這台裝置': 'Signed out. Guest progress is saved on this device',
    '帳號已刪除，正在建立訪客進度': 'Account deleted. Preparing guest progress',
    '帳號已刪除，訪客進度保存在這台裝置': 'Account deleted. Guest progress is saved on this device',
  };
  return messages[message] ?? message;
}
```

#### 1.12.7 Import error translations (developer import & custom CSV)

_Verbatim from `App.tsx` lines 10245-10273:_

```ts
function developerVocabularyMessageForMode(message: string, studyMode: StudyMode): string {
  if (studyMode !== 'chinese') {
    return message;
  }

  const staticMessages: Record<string, string> = {
    '匯入檔案是空的。': 'The import file is empty.',
    'JSON 需要是陣列，或包含 words 陣列。': 'JSON must be an array or include a words array.',
    'JSON 格式無法讀取。': 'Could not read the JSON format.',
    'CSV 至少需要標題列和一筆資料。': 'CSV needs a header row and at least one data row.',
    'CSV 需要 word 或 id 欄位，才能對應要修改的單字。': 'CSV needs a word or id column so rows can be matched.',
  };
  if (staticMessages[message]) {
    return staticMessages[message];
  }

  const displayRowName = (rowName: string) => rowName.replace(/^第 (\d+) 筆$/, 'row $1');
  const missingFields = message.match(/^(.+) 不是既有單字，也缺少新增單字需要的完整欄位。$/);
  if (missingFields) {
    return `${displayRowName(missingFields[1])} is not an existing word and is missing required fields for a new word.`;
  }

  const duplicateRow = message.match(/^(.+) 的 id 或單字重複。$/);
  if (duplicateRow) {
    return `${displayRowName(duplicateRow[1])} has a duplicate id or word.`;
  }

  return message;
}
```

Error strings generated by the parsers (zh): `匯入檔案是空的。`, `JSON 需要是陣列，或包含 words 陣列。`, `JSON 格式無法讀取。`, `CSV 至少需要標題列和一筆資料。`, `CSV 需要 word 或 id 欄位，才能對應要修改的單字。`, `<row> 不是既有單字，也缺少新增單字需要的完整欄位。`, `<row> 的 id 或單字重複。` (row name = word, id, or `第 N 筆`); custom-set CSV: `CSV 需要 word 和 meaning 欄位。`, `第 N 筆缺少 word 或 meaning。`, `<word> 已存在，已略過。` (the last three have no English translation in the source).

#### 1.12.8 Scan screen copy

_Verbatim from `src/components/ScanWordsView.tsx` lines 17-88:_

```ts
const copy = {
  english: {
    back: '返回',
    title: '掃描單字表',
    intro: '拍下或選一張單字表照片，App 會在手機上讀出英文單字和紙上印的中文意思。照片不會上傳。',
    tips: ['光線充足、紙張拍正', '一次拍一頁，字不要太小', '英文和中文意思要在同一行、同一列，或意思在單字正下方'],
    takePhoto: '拍照',
    choosePhoto: '從相簿選擇',
    pasteTitle: '或貼上文字',
    pasteHint: '在「照片」App 長按文字即可拷貝（原況文字），再貼到這裡',
    pastePlaceholder: 'abandon v. 放棄\nbenefit n. 好處',
    readPasted: '讀取貼上的文字',
    unavailable: '這個版本還不能直接辨識照片。請更新到最新的 iPhone App，或先用下方「貼上文字」。',
    reading: '正在手機上辨識…',
    readFailed: '辨識失敗，請換一張更清楚的照片再試一次。',
    cameraDenied: '沒有相機權限，請到「設定」允許 Word7000 使用相機，或改從相簿選擇。',
    found: (count: number) => `找到 ${count} 個單字`,
    reviewHint: '儲存前可以直接修改英文或中文；取消勾選的不會存入。',
    noneFound: '沒有找到成對的英文和中文意思。可以換一張更清楚的照片，或用「新增一列」手動加入。',
    word: '英文',
    meaning: '中文意思',
    pos: '詞性',
    addRow: '新增一列',
    removeRow: '刪除這一列',
    includeRow: (word: string) => `存入 ${word || '這一列'}`,
    saveTo: '存到',
    newBank: '新字庫',
    existingBank: '現有字庫',
    bankName: '字庫名稱',
    save: (count: number) => `存入字庫（${count} 個）`,
    rescan: '重新掃描',
    savedTitle: '已存入字庫',
    savedText: (count: number, name: string) => `${count} 個單字已加入「${name}」，學習、測驗和字庫都已切換到這個字庫。`,
    startStudy: '開始學習',
    scanAnother: '再掃一張',
  },
  chinese: {
    back: 'Back',
    title: 'Scan a Word Sheet',
    intro: 'Take or choose a photo of a vocabulary sheet. The app reads each English word and the Chinese meaning printed next to it, on your phone. The photo is not uploaded.',
    tips: ['Good light, paper flat and straight', 'One page per photo, text not too small', 'Meaning on the same line, in the same row, or right under the word'],
    takePhoto: 'Take Photo',
    choosePhoto: 'Choose Photo',
    pasteTitle: 'Or paste text',
    pasteHint: 'In Photos, touch and hold text to copy it (Live Text), then paste it here',
    pastePlaceholder: 'abandon v. 放棄\nbenefit n. 好處',
    readPasted: 'Read Pasted Text',
    unavailable: 'This version cannot read photos yet. Update to the latest iPhone app, or use "Paste text" below.',
    reading: 'Reading on your phone...',
    readFailed: 'Could not read that photo. Try a clearer one.',
    cameraDenied: 'Camera access is off. Allow it for Word7000 in Settings, or choose a photo instead.',
    found: (count: number) => `${count} words found`,
    reviewHint: 'Fix any word or meaning before saving. Unchecked rows are skipped.',
    noneFound: 'No word and meaning pairs were found. Try a clearer photo, or add rows by hand.',
    word: 'English',
    meaning: 'Chinese meaning',
    pos: 'Part',
    addRow: 'Add Row',
    removeRow: 'Delete this row',
    includeRow: (word: string) => `Save ${word || 'this row'}`,
    saveTo: 'Save to',
    newBank: 'New bank',
    existingBank: 'Existing bank',
    bankName: 'Bank name',
    save: (count: number) => `Save ${count} Words`,
    rescan: 'Scan Again',
    savedTitle: 'Saved',
    savedText: (count: number, name: string) => `${count} words were added to "${name}". Study, quiz and library now use this bank.`,
    startStudy: 'Start Studying',
    scanAnother: 'Scan Another',
  },
} as const;
```

#### 1.12.9 Personal analytics copy (zh UI then English UI)

_Verbatim from `src/components/PersonalAnalyticsView.tsx` lines 533-579:_

```ts
const zhCopy = {
  activeDays: '活躍天數',
  activityTrend: '學習趨勢',
  back: '返回我的',
  bestDay: '最佳學習日',
  bestStreak: '最佳連勝',
  chineseMode: '中文單字',
  currentStreak: '目前連勝',
  dailyAverage: '活躍日平均',
  dataNote: '詳細趨勢從本版本開始累積；升級前只能保留可確認的今日總量。',
  days: (value: number) => `${value} 天`,
  difficultWords: '困難單字',
  englishMode: '英文單字',
  eyebrow: 'PERSONAL INSIGHTS',
  goalDays: '30 天達標日',
  dailyGoalLine: '每日目標線',
  goalProgress: (current: number, target: number) => current >= target ? '今日目標已完成' : `目標 ${current}/${target}`,
  learningMethods: '學習方式',
  learningMinutes: '有效學習分鐘',
  learningSessions: '學習時段',
  learningResults: '學習成果',
  mastered: '已掌握',
  masteryRate: '熟練度',
  modeMix: '模式分布',
  noAccuracy: '尚無正確率',
  notStudied: '未學習',
  personalInsight: '個人學習建議',
  quizAttempts: '測驗作答',
  recordedActions: '累積記錄',
  reviewWords: '待複習',
  selectedActions: (count: number) => `${count} 次學習行動`,
  speakingCards: '口說完成',
  speakingSkipped: (count: number) => `查看答案 ${count}`,
  streakRecord: '連勝與累積',
  studyCards: '單字卡判斷',
  subtitle: '從每天的行動看見真正的學習節奏',
  thisWeek: '本週學習次數',
  title: '你的學習分析',
  todayActions: '今日行動',
  weeklyChange: '較前一週',
  focus: {
    consistency: '本週活躍天數偏少。先把目標縮小到每天 5 個單字，比一次大量學習更容易維持。',
    momentum: '你的學習節奏穩定。維持目前頻率，並優先清掉待複習單字，可以讓熟練度持續上升。',
    quiz: '最近測驗正確率偏低。先回到複習清單加強容易混淆的單字，再重新測驗會更有效。',
    review: '待複習單字正在累積。下一次學習先使用「複習」篩選，避免舊單字被新內容蓋過。',
  },
} as const;
```

_Verbatim from `src/components/PersonalAnalyticsView.tsx` lines 581-627:_

```ts
const enCopy = {
  activeDays: 'Active days',
  activityTrend: 'Learning trend',
  back: 'Back to profile',
  bestDay: 'Best day',
  bestStreak: 'Best streak',
  chineseMode: 'Chinese words',
  currentStreak: 'Current streak',
  dailyAverage: 'Avg. per active day',
  dataNote: 'Detailed trends start with this version. Earlier data only includes totals that can be verified.',
  days: (value: number) => `${value} days`,
  difficultWords: 'Difficult words',
  englishMode: 'English words',
  eyebrow: 'PERSONAL INSIGHTS',
  goalDays: 'Goal days in 30',
  dailyGoalLine: 'Daily goal line',
  goalProgress: (current: number, target: number) => current >= target ? 'Daily goal complete' : `Goal ${current}/${target}`,
  learningMethods: 'Learning methods',
  learningMinutes: 'Active minutes',
  learningSessions: 'Learning sessions',
  learningResults: 'Learning results',
  mastered: 'Mastered',
  masteryRate: 'Mastery rate',
  modeMix: 'Mode mix',
  noAccuracy: 'No accuracy yet',
  notStudied: 'Not studied',
  personalInsight: 'Personal recommendation',
  quizAttempts: 'Quiz answers',
  recordedActions: 'Recorded actions',
  reviewWords: 'Need review',
  selectedActions: (count: number) => `${count} learning actions`,
  speakingCards: 'Speaking completed',
  speakingSkipped: (count: number) => `${count} viewed answer`,
  streakRecord: 'Streak and totals',
  studyCards: 'Study card decisions',
  subtitle: 'See the learning rhythm behind your daily practice',
  thisWeek: 'Actions this week',
  title: 'Your learning analytics',
  todayActions: 'Today',
  weeklyChange: 'vs. prior week',
  focus: {
    consistency: 'You were active on fewer than three days this week. A smaller daily target is more sustainable than one large session.',
    momentum: 'Your learning rhythm is steady. Keep the frequency and clear review words first to continue raising mastery.',
    quiz: 'Recent quiz accuracy is low. Review confusing words first, then retry the quiz for stronger recall.',
    review: 'Review words are building up. Start your next session with the Review filter before adding more new words.',
  },
} as const;
```

#### 1.12.10 Other hard-coded strings

| Where | String |
|---|---|
| Quiz result eyebrow | `RESULT` (choice), `SPEAKING` (speaking) — both UIs |
| Quiz header | `QUIZ {n} / {total}`, `SPEAKING {n} / {total}` |
| Dictionary close a11y | zh `關閉查字`, en `Close dictionary` |
| Set-picker close a11y | zh `關閉`, en `Close` |
| Sets detail footer | `{customWords.length} Custom` |
| Email placeholder | `Email` |
| Default new set name | `我的單字集` (both UIs) |
| Default scan bank name | zh UI `掃描 {M}/{D}`, English UI `Scan {M}/{D}` |
| Custom word defaults | example `I want to remember the word {word}.`, exampleZh `我想記住 {word} 這個單字。`, POS `n`, pronunciation `/{word}/`, group `Custom` |
| Live Activity footer | `Word7000`; compact leading in noon mode `W7` |
| Install guide steps | web-only (see `installGuideStepsByMode` in App.tsx) — drop |

---

## 2. Study modes (`english` ↔ `chinese`)

Toggle: Home → mode row. Unless conserving resources (Low Power Mode or Reduce Motion), a full-screen overlay fades in over 210 ms (scale 0.94→1, y 18→0), the mode flips, the overlay holds 220 ms and fades out over 260 ms. Overlay: big `character.bubble` icon (`#007AFF` for target `english`, `#5856D6` for `chinese`, Chinese variant uses an indigo-tinted panel), `overlayTitle`, `overlayText` of the **target** mode. Persist to `word7000-study-mode-v1`.

What flips:

| Aspect | `english` (zh-TW UI, default) | `chinese` (English UI) |
|---|---|---|
| All UI copy | `.english` objects (Chinese text) | `.chinese` objects (English text) |
| Tab labels | 首頁 學習 測驗 字庫 我的 | Home **Chinese** Quiz Library Me |
| Word "primary" text (cards, rows, quiz prompt, set lists, toast messages) | `word.word` | concise Chinese meaning (§4.3) |
| Pinyin line | none | pinyin of concise meaning (§4.3) |
| Secondary line | `pronunciation` (shown on front and back) | `"<word> <pronunciation>"` (**back only** — it is the answer) |
| Meaning detail | concise Chinese meaning | English word |
| Meaning label on card back | part of speech | `englishCounterpart` |
| Supplemental formatting | parts joined ` · ` | each part followed by its pinyin, joined ` · ` |
| Example primary / secondary | `example` / `exampleZh` | `exampleZh` / `example` |
| Quiz options (`answerMode`) | `meaningZh` of 4 words (`'meaning'`) | English `word` of 4 words (`'word'`) |
| Quiz answer text (result, missed list) | concise Chinese meaning | English word |
| Speaking prompts | §3.10 English questions | §3.10 Chinese-keyword questions |
| Empty study / library title | `noStudyWords` / `noLibraryWords` | `noChineseWords` |
| Live Activity text + `app_locale` sent to server | Chinese, `zh-TW` | English, `en` |
| Default scan bank name | `掃描 M/D` | `Scan M/D` |
| Analytics counter incremented per action | `englishActions` | `chineseActions` |
| Analytics screen copy | `zhCopy` | `enCopy` |

Not changed: the word data, progress (one progress record serves both modes — knowing "adapt" in either direction marks the same word), filters, first-letter filter (always the English word's first letter), sort (always English A-Z), Core level names.

Changing mode resets the quiz to setup and rebuilds the study session (mode is part of the session source key).

---

## 3. Learning engine

Reference implementation: `src/lib/progress.ts`, `src/lib/studySession.ts`, `src/lib/learningAnalytics*.ts`, `src/lib/conversationPrompts.ts`, `src/lib/chineseDisplay.ts`. Port the functions 1:1 as pure Swift functions on value types and port `progress.test.ts`, `studySession.test.ts`, `learningAnalytics.test.ts`, `conversationPrompts.test.ts` as XCTest.

### 3.1 Progress data model (JSON — this exact shape is stored locally AND in Supabase `profiles.progress`)

```jsonc
// ProgressState
{
  "dailyTarget": 20,               // number, required. Default 20. Settings offers 10/20/30/50; setter clamps round(x) to 5…100
  "streak": 3,                     // number, required
  "studiedToday": 12,              // number, required: distinct words graded on dailyProgressDate
  "dailyProgressDate": "2026-10-10", // optional string (YYYY-MM-DD)
  "lastStudyDate": "2026-10-10",     // optional string: last day any word was graded
  "words": {                       // required object: wordId -> WordProgress (only touched words)
    "w0001": {
      "status": "mastered",        // "new" | "mastered" | "review" (required)
      "favorite": false,           // required bool
      "difficult": false,          // required bool (true after "review")
      "reviewCount": 1,            // required number: times marked "review"
      "dueDate": "2026-10-17",     // optional: next review date
      "stage": 3,                  // optional: SRS box 0…7
      "lapses": 1,                 // optional: mastered -> review transitions
      "lastStudied": "2026-10-10", // optional: last graded date
      "statusUpdatedAt": "2026-10-10T08:05:00.000Z", // optional ISO
      "favoritedAt": "…ISO…",      // optional, present only while favorite
      "favoriteUpdatedAt": "…ISO…" // optional
    }
  },
  "analytics": {                   // optional (§3.11)
    "version": 1,
    "bestStreak": 5,
    "days": { "2026-10-10": { "<sourceId>": { /* DailyLearningCounters */ } } }
  }
}
```

Validation when reading (anything failing → treat as absent / use fallback): `dailyTarget`, `streak`, `studiedToday` numbers; `dailyProgressDate`/`lastStudyDate` absent or string; `analytics` absent or valid (§3.11); `words` a non-array object where every value has boolean `favorite`, boolean `difficult`, number `reviewCount`, `status` ∈ {new, mastered, review}, and `favoriteUpdatedAt`/`dueDate`/`lastStudied` absent-or-string, `stage` absent-or-number. Unknown extra fields must be **preserved** when re-saving (use a tolerant Codable with raw passthrough, or keep a `[String: JSONValue]` bag) so old and new clients do not strip each other's data.

A word with no entry is `{status: new, favorite: false, difficult: false, reviewCount: 0}`.

Initial state: `{dailyTarget: 20, streak: 0, studiedToday: 0, dailyProgressDate: <today>, words: {}}`.

### 3.2 Statuses

* `new`: never graded. Not due, not counted in mastered/review.
* `mastered` ("已會 / Known"): last grade was correct. Due at `dueDate`.
* `review` ("複習 / Review"): last grade was "don't know" or a wrong quiz answer. Always due (dueDate = that day).
* `favorite` is an orthogonal flag (requires a permanent account to set; §7.6).

### 3.3 Spaced repetition

```
REVIEW_INTERVAL_DAYS = [0, 1, 3, 7, 14, 30, 60, 120]   // index = stage
MAX_REVIEW_STAGE = 7
KNOWN_ON_FIRST_SIGHT_STAGE = 3     // new word marked known in Study -> due in 7 days
RECOGNISED_IN_QUIZ_STAGE = 1       // new word answered correctly in Quiz -> due tomorrow
```

`reviewStage(p)`: `p == nil || p.status == new` → 0; `p.stage` finite → `clamp(round(stage), 0, 7)`; legacy (no stage) → 3 if mastered else 0.

`reviewDueDate(p)`: `nil`/new → **nil** (never due); `p.dueDate` if set; else anchor = `p.lastStudied ?? statusUpdatedAt.prefix(10)`; no anchor → `"0000-00-00"` (always due); else `addDays(anchor, INTERVAL[reviewStage(p)])`.

`isWordDue(p, today)` = dueDate != nil && dueDate <= today (string compare).

**Grade "known"** (`markKnown`, first-sight stage 3) and **quiz correct** (`markQuizCorrect`, first-sight stage 1) share `gradeWord`:
```
alreadyGradedToday = p.lastStudied == today && p.status == mastered
stage = p.status == new        ? firstSightStage
      : alreadyGradedToday     ? reviewStage(p)                  // no stage-skipping within a day
      : min(7, max(1, reviewStage(p) + 1))
p' = p with status=mastered, difficult=false, stage, dueDate=addDays(today, INTERVAL[stage]),
     lastStudied=today, statusUpdatedAt=now          // reviewCount, lapses, favorite untouched
```
**Grade "review"** (`markReview`; also wrong quiz answers):
```
p' = p with status=review, difficult=true, dueDate=today,
     lapses = (p.lapses ?? 0) + (p.status == mastered ? 1 : 0),
     reviewCount = p.reviewCount + 1, lastStudied=today, stage=0, statusUpdatedAt=now
```
Both go through the daily-progress update (§3.4) **before** the word update. `toggleFavorite` does not touch daily progress: `favorite = !favorite; favoriteUpdatedAt = now; favoritedAt = favorite ? now : nil`.

### 3.4 Daily target, studied-today and streak

```
normalizeProgressForDate(s, today):
  if s.dailyProgressDate != today: s.dailyProgressDate = today; s.studiedToday = 0
  if s.lastStudyDate != nil && s.lastStudyDate != today && !isYesterday(s.lastStudyDate, today): s.streak = 0
advanceDailyProgress(s, today, increment):      // called for every grade
  s = normalize(s, today)
  streak = s.lastStudyDate == today ? s.streak
         : (s.lastStudyDate != nil && isYesterday(s.lastStudyDate, today)) ? max(1, s.streak + 1)
         : 1
  s.dailyProgressDate = today; s.lastStudyDate = today; s.streak = streak; s.studiedToday += increment
increment = (previous word.lastStudied != today) ? 1 : 0   // goal counts DISTINCT words per day
```
* `normalizeProgressForDate` runs on load, after every merge, and whenever the local date changes while running.
* Streak advances on the first grade of a day (study known/review, quiz correct/wrong). Speaking practice, favorites, opening screens do **not** count.
* Goal reached ⇔ `studiedToday >= dailyTarget`. `dailyPercent = min(100, round(studiedToday/dailyTarget*100))`.
* Study session size = `max(5, dailyTarget)`.
* `addDays`/`isYesterday` operate on validated `YYYY-MM-DD` strings (invalid → nil/false).

### 3.5 Word pools (study, quiz, library)

`filterWords(words, progress, query, filter, {level, initial, sort})` (§4.4 has the search part):
* If no query, filter `all`, level `all`, initial `all` → return `words` as-is (or the alphabetical copy if sort = alphabetical).
* Otherwise iterate in source order (bank order, or alphabetical order if sorted), keep words that match: `level` (word.group == level), `initial` (uppercased English word starts with the letter), query score > 0 (if querying), status filter (`favorites` → favorite; `review`/`mastered`/`new` → status).
* Re-sort (only when sort != alphabetical and (querying or filter ∈ {favorites, review, mastered})): by score desc (if querying), then by recency desc (favorites: `favoritedAt`; review/mastered: `statusUpdatedAt ?? lastStudied`; parse as date, unparseable → 0), then original index asc. **Use a stable sort with explicit index tiebreak in Swift.**
* Alphabetical order: `localeCompare(a.word, b.word, 'en', sensitivity: base)` then original index → Swift: `a.word.compare(b.word, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))`.

Study pool = `filterWords(bankWords, progress, '', studyFilter, {studyLevel, studyInitial})`. Quiz pool = same with quiz filters. Library = with the query and library sort.

### 3.6 Building a study session

```
buildStudyQueue(pool, progress, today, limit = max(5, dailyTarget), seed = "<ms>:<random>"):
  due = [], fresh = [], ahead = []
  for word in pool (in pool order):
    d = reviewDueDate(progress.words[word.id])
    if d == nil        -> fresh.append(word)
    elif d <= today    -> due.append((d, word, struggling: status == review))
    else               -> ahead.append((d, word))
  due.sort  by date asc, then struggling first          (stable)
  ahead.sort by date asc                                 (stable)
  chosen = (due + fresh + ahead).prefix(limit)
  return shuffleWithSeed(chosen, "\(seed):queue")
```
i.e. overdue reviews first (oldest first, "review"-status before "mastered" on the same date), then never-seen words in library order, and only if both run out, known words ahead of schedule. The chosen cards are shuffled.

Session object (in memory only, never persisted):
```
StudySession { cardIds: [String]   // order shown, including re-queued misses (deduped on creation)
               index: Int; initialCount: Int; knownIds: [String]; reviewIds: [String]
               requeued: [String: Int]; sourceKey: String }
```
* **Source key** = `[studyMode, studyFilter, studyLevel, studyInitial, activeBankId, developerVocabulary.importedAt ?? "", bankWords.count].joined("|")`. Progress is deliberately NOT part of it.
* A new session is built when progress is loaded and (there is no session OR its sourceKey differs from the current one). The session is also cleared (→ rebuilt) on sign-in/activation, sign-out and account deletion.
* Explicit sessions: "review missed" uses `session.reviewIds` (in order); "practice quiz misses" uses the quiz's missed ids; both keep the current source key, no shuffle.
* Home start button: if the current session is complete, build a new one first.

`gradeStudyCard(session, cardId, grade)` (ignored unless `cardId == cardIds[index]`):
```
STUDY_REQUEUE_GAP = 4; MAX_REQUEUES_PER_CARD = 2
if grade == review && requeued[cardId] < 2:
    insertAt = min(cardIds.count, index + 1 + 4); insert cardId at insertAt; requeued[cardId] += 1
remove cardId from knownIds and reviewIds; append to knownIds or reviewIds   // summary = last answer
index += 1
```
Progress display: `done = min(index, cardIds.count)`, `total = cardIds.count` (grows when misses are re-queued). Complete ⇔ `index >= cardIds.count` (and session non-nil).

### 3.7 Grading and undo

On grade (swipe or button), for the current card id:
```
before = progress
after  = recordLearningEvent(before, grade == known ? markKnown(before, id, today) : markReview(before, id, today),
                             type: grade == known ? studyKnown : studyReview)      // §3.11
session = gradeStudyCard(session, id, grade)
undo = (before, after, sessionBeforeGrade)
progress = after
maybePromptToProtectProgress()   // §7.6
```
Undo is available iff an undo record exists AND `progress` is still exactly `after` (any other progress mutation — favorite toggle, quiz answer, learning-duration flush, day rollover, sync merge — invalidates it; in Swift keep a monotonically increasing `progressRevision` and compare). Undo restores `before` (including analytics and studiedToday) and the pre-grade session; one level only. New sessions clear undo.

### 3.8 Quiz generation

* `quizQuestionCounts = [10, 20, 50]`, default 10 (persisted). Session count = `min(requested, pool.count)`.
* `buildQuizSession(pool, n, seed)`: if `n == 0` → []; if `n == pool.count || n > pool.count/3` → `shuffleWithSeed(pool, seed).prefix(n)`; else `sampleDistinctIndexes(pool.count, n, "\(seed):session")` mapped to words (insertion order of the sampled set).
* Quiz seed = `"<Date.now()>:<Math.random()>"` at start; per-question option seed = `"\(quizSeed):\(index)"`.
* Option source: the quiz pool if it has ≥ 3 words, else the whole active bank if ≥ 3, else the core vocabulary.
* `buildQuizOptions(source, wordId, seed, answerMode)`:
  ```
  QUIZ_OPTION_COUNT = 4; QUIZ_DISTRACTOR_SAMPLE = 48
  correctIndex = index of wordId in source (or 0); correctText = answerText(correct)  // 'meaning' -> meaningZh, 'word' -> word
  candidates = sampleDistinctIndexes(source.count, min(48, max(0, count-1)), "\(seed):wrong:\(wordId)", exclude: correctIndex)
               .enumerated().map { order, i in (order, score: (pos(i)==pos(correct) ? 2 : 0) + (group(i)==group(correct) ? 1 : 0), word) }
  sort candidates by score desc, then order asc
  take up to 3 whose answer text is non-empty and not already used (dedupe incl. correctText)
  return shuffleWithSeed([correct] + wrong, "\(seed):options:\(wordId)")
  ```
  POS normalization `primaryPartOfSpeech(pos)`: first token of `pos.split(/[\s/,.]+/)` lowercased; if it starts with `v` → `"v"` (so `v`, `vt`, `vi` match). E.g. `"vt / vi"` → `v`, `"n / a / vt"` → `n`, `"a"` → `a`.
  Note: options use the raw `meaningZh` (for the built-in list this is already a single primary meaning); the result card uses the concise meaning.
* Answering (once per `seed:index:wordId`): lock the currently displayed options and word; correct → `correctCount += 1`, progress `markQuizCorrect`, analytics `quizCorrect`; wrong → append id to `missedIds` (unique), progress `markReview`, analytics `quizWrong`; then `maybePromptToProtectProgress()`.
* Next: clears result; if `index >= session.count − 1` → finished (results card); else `index += 1`.

### 3.9 Deterministic PRNG (port exactly so tests match)

```
hashText(s): h = 2166136261; for each UTF-16 code unit c of s: h ^= c; h = imul32(h, 16777619); return h as UInt32   // FNV-1a over UTF-16
next(x) = (x * 1664525 + 1013904223) mod 2^32
scramble(x): x ^= x >> 16; x = imul32(x, 0x85ebca6b); x ^= x >> 13; x = imul32(x, 0xc2b2ae35); x ^= x >> 16   // murmur3 fmix32
shuffleWithSeed(values, seed): a = copy; r = hashText(seed.isEmpty ? "word7000" : seed)
    for i in (1..<a.count).reversed(): r = next(r); j = scramble(r) % (i+1); swap(a[i], a[j])
sampleDistinctIndexes(len, count, seed, excluded = -1):
    if len <= 0 || count <= 0: return []
    target = min(count, len - (excluded >= 0 ? 1 : 0)); r = hashText(seed or "word7000"); set = OrderedSet()
    while set.count < target: r = next(r); i = scramble(r) % len; if i != excluded: set.insert(i)
    return Array(set)            // insertion order
```
Use `UInt32` wrapping arithmetic (`&*`, `&+`). Runtime seeds are random, so exact parity only matters for unit tests.

### 3.10 Speaking practice

Same session machinery as the choice quiz (same pool, count, order). For the visible word, `buildConversationPrompt(word, mode)` produces `{keyword, keywordPronunciation, question, questionSupport, referenceAnswer, referenceTranslation}` — port `src/lib/conversationPrompts.ts` **1:1** (keyword lists, 20 exact-word questions per mode, topic matching against `"<word lowercased> <meaningZh lowercased>"`, part-of-speech fallbacks via `pos.lowercased().split(/[\/,;]/)[0].trim()` with `startsWith('v')`, `'adv'`, `'a'`). English mode: keyword = word, no pronunciation, support `Try to answer in 2-3 sentences and include "<word>" naturally.`, reference answer = `example + " I would add one personal reason or example to make the answer sound natural."`, translation = `exampleZh + " 我會再補上一個自己的原因或例子，讓回答聽起來更自然。"`. Chinese mode: keyword = first part of the concise meaning, pronunciation = its pinyin, support `Try to answer in Chinese and include "<kw>" once. English hint: "<word>".`, reference = `exampleZh + " 我會再補上一個自己的原因或例子，讓回答更像真實對話。"`, translation = `example + " I would add one personal reason or example to make the answer sound natural."`.

Revealing (either button) records exactly one analytics event per question: `speakingCompleted` ("I finished speaking") or `speakingSkipped` ("show sample answer"). Speaking does **not** change word progress, studiedToday or streak. There is no audio/recording/speech recognition.

### 3.11 Learning analytics (stored inside progress)

```
DailyLearningCounters { activeSeconds, chineseActions, englishActions, otherActions, quizCorrect, quizWrong,
                        speakingCompleted, speakingSkipped, sessions, studyKnown, studyReview }   // all non-negative safe ints
LearningAnalyticsState { version: 1, bestStreak: Int, days: [YYYY-MM-DD: [sourceId: DailyLearningCounters]] }
```
* `sourceId` = this device's streak device id (`word7000-streak-device-id-v1`, e.g. `ios-mgk3x2a1-k2j3h4g5f6`); the pseudo-source `legacy` holds pre-analytics totals. Keep the migrated device id so this device continues its own source bucket.
* `recordLearningEvent(before, after, {date, mode, sourceId, type})`: start from `cloneOrSeed(before, date)`, increment `type` and `chineseActions` (mode chinese) or `englishActions` in `days[date][sourceId]`, keep only the **400 most recent** dates, `bestStreak = max(old, after.streak)`, attach to `after`.
* `recordLearningDuration(progress, {date, mode, seconds, sourceId})`: `seconds = clamp(round(s), 0, 21600)`; ignore if < 5; else `activeSeconds += seconds; sessions += 1`. A timing session starts when the Study or Quiz tab is visible and the app is active, and is flushed when leaving those tabs, backgrounding, or when date/mode changes (date = start date).
* `cloneOrSeed(progress, today)`: if analytics exists: if `(dailyProgressDate ?? lastStudyDate) == today`, add `max(0, studiedToday − goalActions(today))` to `days[today]["legacy"].otherActions`; `bestStreak = max(bestStreak, streak)`. If absent: seed `{bestStreak: streak, days: today ? {legacy: {otherActions: studiedToday}} : {}}`.
* `total(c) = other + quizCorrect + quizWrong + speakingCompleted + speakingSkipped + studyKnown + studyReview`; `goal(c) = total − speaking*`. A day's counters = sum over its sources.
* `buildPersonalLearningAnalytics(progress, stats, vocabCount, today)`:
  ```
  chart30 = for the 30 local dates ending today: {date, actions: total, goalActions: goal}
  chart7 = last 7 of chart30; previous7 = chart30[-14..<-7]
  totals = sum of counters over ALL stored days
  quizAttempts = quizCorrect + quizWrong; quizAccuracy = attempts > 0 ? round(correct/attempts*100) : nil
  weeklyActions = Σ chart7.actions; prev = Σ previous7.actions
  weeklyChangePercent = prev > 0 ? round((weekly-prev)/prev*100) : (weekly > 0 ? 100 : nil)
  activeDays7/30 = count(actions > 0); averagePerActiveDay30 = activeDays30 > 0 ? round(Σchart30/activeDays30) : 0
  bestDay = all stored days max by actions, tie -> later date (display "–" if 0)
  bestStreak = max(progress.streak, analytics.bestStreak)
  goalDays30 = count(chart30.goalActions >= dailyTarget)
  mastered = stats.mastered; reviewWords = difficultWords = stats.review
  masteryRate = vocabCount > 0 ? round(mastered/vocabCount*100) : 0
  learningMinutes = round(totals.activeSeconds / 60); sessions = totals.sessions
  studyActions = studyKnown + studyReview + otherActions; todayActions = chart30.last.actions
  totalActions = Σ total over all stored days; englishActions / chineseActions = totals
  focus = (attempts >= 5 && accuracy < 70) ? quiz : reviewWords >= 8 ? review : activeDays7 < 3 ? consistency : momentum
  ```
* `computeStats(words, progress, today?)` over progress entries whose id is in `words`: `mastered`, `review`, `favorites`, `due` (only if today given), `remaining = words.count − mastered − review`, `studiedToday = progress.studiedToday`. Home/Profile use the **active bank** words and today; the Stats screen uses **all words** and no `today` (due = 0).
* Merge (multi-device): per date, per source, per counter **max**; `bestStreak` max (§7.5).

### 3.12 Account-protection nudge

After a grade or quiz answer, if the user is an anonymous Supabase user and the flag `word7000-account-protection-prompt-v1` is not `"seen"`: write `"seen"`, then after 650 ms open the account-upgrade sheet with reason `protectProgress`. Shown once per device.

---

## 4. Word data

### 4.1 Shape and contents

```ts
type WordEntry = {
  id: string;                     // "w0001" … "w7000" (built-in); "custom-…" (manual/CSV); "scan-…" (scanned)
  word: string;                   // built-in: lowercase a-z, 2–18 letters, unique
  partOfSpeech: string;           // e.g. "vt / vi", "n / a / vt", "a", "prep / adv", "conj"
  pronunciation: string;          // KK-ish, e.g. "/ә'dæpt/"
  meaningZh: string;              // primary Traditional-Chinese meaning, e.g. "適應"
  supplementalMeaningZh?: string; // extra meanings separated by "；", may be "" (e.g. "調整；改編")
  example: string;                // English sentence containing the word
  exampleZh: string;              // zh-TW translation
  group: string;                  // "Core 1" … "Core 14" (500 each, by list position: floor(index/500)+1); "Custom"; "Scan"
};
```
`src/data/words.ts` exports `sampleWords: WordEntry[]` — exactly 7000 entries (ids w0001…w7000 in order). It is generated by `scripts/generate-word-data.mjs`.

**`reviewed-examples-core*.json` / `reviewed-meanings-core*.json` are NOT merged at runtime.** They are build-time inputs to `generate-word-data.mjs` (approved example sentences and primary/supplemental meanings per word) whose output is already baked into `words.ts`. For the native app, export `sampleWords` once to `words.json` and bundle it (≈3 MB; consider a compact array-of-arrays or a precompiled binary plist / SQLite if launch time matters), e.g.:
```bash
node --experimental-strip-types --input-type=module -e "import {sampleWords} from './src/data/words.ts'; import fs from 'node:fs'; fs.writeFileSync('ios/words.json', JSON.stringify(sampleWords))"
# (or: npx tsx -e "...") — add the pinyin columns in the same script with pinyin-pro (see §4.3)
```
Add a build check that the JSON has 7000 entries with unique ids/words.

### 4.2 The vocabulary the app actually uses

* `baseVocabulary` = developer preview words if a preview is stored (§6.3 `word7000-developer-vocabulary-v1`), else the bundled 7000.
* `vocabularyWords` (the **core bank**) = `mergeCustomWords(baseVocabulary, nonScannedCustomWords)`: custom words whose id AND lowercase word do not collide with a base word, **prepended** before the base list.
* `allWords` = scanned custom words + `vocabularyWords` (used for id lookups, Home dictionary, word detail, stats screen, set lists).
* `bankWords` = active bank's words (§5.1). Study, Quiz, Library, Home ring/stats use `bankWords`.

### 4.3 Chinese display helpers (`src/lib/chineseDisplay.ts`)

* `meaningParts(m)` = split on any of `；;，,、`, trim, drop empty, dedupe (first occurrence).
* `conciseChineseMeaning(m)` = first 2 parts joined with `；` (or `m.trimmed` if no parts). This is the "primary" meaning everywhere.
* `supplementalChineseMeaning(m)` = parts[2…] joined `；`.
* Word supplemental = `word.supplementalMeaningZh.trimmed` if non-empty, else `supplementalChineseMeaning(word.meaningZh)`.
* `chineseMeaningPinyin(m)` = for each part: pinyin of each Han character, **no tone marks** (e.g. `shi ying`), syllables separated by spaces, non-Chinese characters removed; parts joined `；`. Library used: `pinyin-pro` with overrides `調整 → tiao zheng`, `敢於 → gan yu`.
  **Native recommendation:** precompute pinyin for the concise meaning and for each supplemental part of all 7000 words with the same `pinyin-pro` call at export time and ship it in `words.json` (exact parity, polyphones handled). For custom/scanned words fall back to `CFStringTransform(…, kCFStringTransformToLatin)` + `kCFStringTransformStripDiacritics`, lowercased, keeping only syllables of Han characters.
* Study-card supplemental line: split the word supplemental on `；`; zh UI → join ` · `; English UI → each `"<part> <pinyin(part)>"` joined ` · `. Library detail and quiz result show the raw supplemental string.

### 4.4 Search (Library search and Home quick dictionary)

Query → `trim().lowercased()`, split on whitespace into terms. A word matches only if **every** term matches; its score is the sum of per-term scores; the first matching rule wins per term:

| Field (lowercased) | Rule | Score |
|---|---|---|
| English `word` | equals term | 1000 |
| English `word` | has prefix | 900 |
| English `word` | contains | 760 |
| `meaningZh + " " + supplementalMeaningZh` (trimmed) | contains | 680 |
| `example` | contains | 540 |
| `exampleZh` | contains | 520 |

Results sorted by score desc, then (for favorites/review/mastered filters) recency desc, then original index (unless library sort is alphabetical, in which case alphabetical order is kept and the score only filters). Pronunciation and part of speech are not searched. No pinyin search. Home dictionary: all words, filter `all`, first 36 results, 80 ms debounce.

### 4.5 Groups / levels / filters / sort

* Level options derive from the **current bank**: `all` + distinct `group` values in first-appearance order (core bank: any custom-word groups first, then `Core 1`…`Core 14`). Labels `L1`…`L14` (`"Core "` → `"L"`), `Custom`, `Scan`.
* First-letter filter: `word.word.uppercased().hasPrefix(letter)`.
* Library sort: `default` (bank order) or `alphabetical` (§3.5). Study/quiz have no sort.
* Status filters: `all | favorites | review | mastered | new`. For guests (anonymous or local-only), any persisted `favorites` filter is reset to `all` once the account state is known.

### 4.6 Developer vocabulary import/export (port only if you implement §1.10 option)

Reference `src/lib/developerVocabulary.ts`. CSV export columns: `id,word,pronunciation,partOfSpeech,meaningZh,supplementalMeaningZh,example,exampleZh,group` (quote cells containing `",\n\r`, double quotes). Import accepts JSON (array, or `{words: [...]}`) or CSV with header aliases (`meaning`, `meaning_zh`, `example_zh`, `pos`, `part_of_speech`, `supplemental_meaning_zh`, …; headers normalized lowercased with spaces/hyphens → `_`). Rows update existing words (by id, else lowercase word) for editable fields (`pronunciation, partOfSpeech, meaningZh, supplementalMeaningZh, example, exampleZh, group`) or add new words when all fields are present (id default `custom-<slug>`). Result snapshot `{importedAt: ISO, summary: importApplied(updated, added, total), words: [WordEntry]}` saved to `word7000-developer-vocabulary-v1`. Device-local only, never synced.

---

## 5. Word banks, custom sets & scanning

### 5.1 Banks

* A "bank" is either the built-in core bank (`id = "core"`) or any custom set. `activeBankId` persisted in `word7000-active-bank-v1` (plain string, default `core`).
* Bank words: core → `vocabularyWords`; set → `set.wordIds` mapped through `allWords` (unknown ids skipped), in `wordIds` order (newest-added first).
* Bank name: set name or `coreBankName`. "Scan bank" ⇔ the set has any id starting with `scan-`.
* If the active set no longer exists (deleted, or belongs to an account that signed out) → fall back to `core` (only after progress has loaded).
* Picker sheet: rows = core (`coreBankName`, subtitle `builtInBank · bankWordCount(coreCount)`) then every set in current custom-set sort (`[scanBankTag · ]bankWordCount(n)`, icon `doc.text.viewfinder` for scan banks else books), ✓ on the active one. Selecting core applies immediately; selecting a set is gated (`customSets`). Bottom: primary `scanNewSheet` (lock icon if not permanent; gated → push scan) and secondary `manage` (gated → push sets). Close via ✕ (`closeSheet`) or backdrop.
* Choosing a bank resets the quiz and rebuilds the study session.

### 5.2 Custom sets data model (local key `word7000-custom-sets-v1[:user:<uid>]`, cloud `profiles.custom_sets`)

```jsonc
// CustomSetState
{
  "sets": [{
    "id": "set-旅行英文-1760083500000",   // "set-" + name with whitespace runs -> "-" + "-" + Date.parse(createdAt) ms; "-2", "-3"… on collision
    "name": "旅行英文",
    "color": "#007AFF",                // cycles customSetSystemColors by sets.count at creation
    "createdAt": "ISO", "updatedAt": "ISO",
    "sortOrder": 1,                    // 1-based creation order; re-numbered after delete
    "wordIds": ["w0123", "custom-hello", "scan-abandon-mgk3x2a1-0"]   // newest first
  }],
  "customWords": [ /* WordEntry objects for custom-/scan- words, newest first */ ],
  "deletedSetIds": { "set-old-1760000000000": "ISO deletedAt" }        // optional tombstones
}
```
Validation: `sets` array of objects with string color/createdAt/id/name/updatedAt, number sortOrder, string-array wordIds; `customWords` an array (entries not validated); `deletedSetIds` absent or string→string map. Empty state `{customWords: [], sets: []}`. Cloud default `{"sets":[],"customWords":[]}`.

Operations (`src/lib/customSets.ts`):
* `createCustomSet(state, name)`: name = `name.trim()` or `我的單字集`; append; color `customSetSystemColors[count % 6]`; sortOrder `count+1`; removes a tombstone with the same id.
* `addWordToSet`: prepend id if absent; bump `updatedAt` (even if already present).
* `removeWordFromSet`: filter; bump `updatedAt`. `renameCustomSet`: ignore empty; bump `updatedAt`.
* `deleteCustomSet`: tombstone `deletedSetIds[id] = now`; remove; renumber sortOrder 1…n.
* `addCustomWordToSet(state, setId, word)`: replace same-id custom word or prepend it; then `addWordToSet`.
* Sort (`word7000-custom-set-sort-v1`, default **`recent`**): `recent` = updatedAt desc; `name` = case-insensitive locale compare; `manual` = sortOrder; ties → sortOrder, then createdAt.
* Merge: §7.5.

UI flows that create/modify sets:
* **Set picker overlay** (from any word's add-to-set button; gated): title `setPickerTitle(primaryWord)`, caption `chooseCustomSet`, close ✕; a name field (`newSetPlaceholder`) + square "create and add" button (creates the set — default name if empty — adds the word, selects it); list of sets (color dot, name, `customSetCount(n)`, trailing `addExistingWord`) or `setPickerEmpty`. Result message `addedToSet(primaryWord, setName)` is stored as the sets screen message.
* **My Sets screen** (push `sets`, back label `返回字庫` / `Back to library` — literal strings in the route; in-detail back = `backToSets`):
  * *List panel*: hero card `setLibrary` / `setLibrarySummary` with name field + `createSet` button; message line (initially `customSetMessageDefault`; then the last action's message); sort chips `customSetSortRecent / customSetSortName / customSetSortManual`; empty state `noCustomSets` + `customSetMessageDefault`; per set a card: tappable header (color dot, name, `customSetCount`, ✓ if selected) that selects it, a gear button (a11y `openSetSettings <name>`) opening the detail panel, and two buttons `startSetStudy` (→ set becomes active bank, go to Study tab) and `startSetQuiz` (→ active bank, reset quiz, go to Quiz tab).
  * *Detail panel* (selected set): header name + count + `startSetStudy`/`startSetQuiz` + destructive `deleteSet` (no confirmation; message `setDeleted`; if it was the active bank → core); rename card `editSetName` field + `saveSetName` (disabled when empty; message `setRenamed`); word list `wordsInSet` with rows (primary word, meaning detail, red `removeFromSet` → message `removedFromSet`), or `emptySetWords`; manual add card `manualWordTitle`/`manualWordIntro` with 7 fields (word, meaning, supplemental, pronunciation, POS, example, exampleZh) + `addManualWord` + `importCustomCsv`; footer `"<n> Custom"`.
  * Panels slide (22 pt x-offset, 0.982 scale) between list/detail.
* **Manual add** (target = selected set, else first set in sort order; no set → message `customSetSelectPlaceholder`; empty word/meaning → message `"<customWordWordPlaceholder> / <customWordMeaningPlaceholder>"`):
  1. If the target set contains any scanned word → build a scanned word (§5.5) from `{word, meaning, POS}` and add it (`customWordAdded`).
  2. Else if a core-bank word with the same lowercase spelling exists → add its id (`addedToSet`).
  3. Else create `{id: "custom-<slug or ms>", group: "Custom", word, meaningZh, supplementalMeaningZh, partOfSpeech || "n", pronunciation || "/word/", example || "I want to remember the word <w>.", exampleZh || "我想記住 <w> 這個單字。"}` where slug = lowercase, non `[a-z0-9]` runs → `-`, trimmed dashes; add via `addCustomWordToSet` (`customWordAdded`). Clear the form.
* **CSV import into a set** (`parseCustomWordsCsv` + `customWordsFromImportRows`): requires header with `word` and `meaning`/`meaningzh` (headers lowercased, spaces/underscores/hyphens removed); optional `supplementalmeaning(zh)`, `example`, `examplezh`, `group` (default `Custom`), `id` (default `custom-<slug>`), `partofspeech`/`pos` (default `n`), `pronunciation` (default `/word/`). Words already in the core bank or duplicated in the file are skipped with errors. Message `customImportApplied(added, rows − added)`. On iOS the RN app shows `importUnsupported` (no file picker) — implement with `.fileImporter` or drop.
* "Selected set" (`selectedCustomSetId`) is in-memory UI state (not persisted), reset on account change; defaults to the first set.

### 5.3 Gating

All custom-set features (picker, sets screen, scan, choosing a non-core bank, manual add/import) require a **permanent** account (§7.6); guests see the lock badges and get the `customSets` upgrade sheet.

### 5.4 Scanning a word sheet (push `scan`)

Native recognizer (`modules/word-scanner/ios/WordScannerModule.swift`, port almost verbatim):
* Load image data from the picked URL → `UIImage` → `cgImage` (error `ERR_WORD_SCANNER_IMAGE` "The photo could not be read.").
* `VNRecognizeTextRequest`, `recognitionLevel = .accurate`, **`usesLanguageCorrection = false`**, `recognitionLanguages` = `["zh-Hant", "en-US"]` filtered by `supportedRecognitionLanguages()` (only set if non-empty).
* `VNImageRequestHandler(cgImage:, orientation: CGImagePropertyOrientation(image.imageOrientation))`.
* For each observation's top candidate: `{text, confidence, x: box.minX, y: 1 − box.maxY, width, height}` (normalized, **origin top-left**). Confidence is ignored by the parser.

Image sources: camera (`requestCameraPermissions`; denied → `cameraDenied` message) or photo library; `mediaTypes: images`, quality 1. Info.plist strings (verbatim):
* `NSPhotoLibraryUsageDescription`: `Word7000 需要讀取你選的照片，在手機上辨識單字表裡的英文與中文意思。照片不會上傳。`
* `NSCameraUsageDescription`: `Word7000 需要使用相機拍下單字表，在手機上辨識英文與中文意思。照片不會上傳。`
* No microphone usage.
Use `PHPickerViewController`/`PhotosPicker` (no permission needed) and `UIImagePickerController(.camera)`.

Screen stages (`start → reading → review → saved`), copy in §1.12.8:
* **start**: back pill (`back`); hero card (scan icon, `title`, `intro`, three ✓ `tips`); `unavailable` notice (never on native); error notice (`readFailed` / `cameraDenied`); buttons `takePhoto` (primary) and `choosePhoto`. Second card `pasteTitle` / `pasteHint`, multiline field (placeholder `pastePlaceholder`, no autocap/autocorrect, min height 120) and `readPasted` (disabled when blank) → `linesFromPlainText`.
* **reading**: spinner + `reading`.
* **review**: back pill becomes `rescan` (→ start, clears rows). Card `found(rows.count)` + `reviewHint` (or `noneFound` when 0 rows). Each row: checkbox (a11y `includeRow(word)`), editable word field (17 bold) + POS field (76 pt) + meaning field, trash button (`removeRow`); unchecked rows dim to 50%. `addRow` appends an empty row. Save card `saveTo` with segmented `newBank` / `existingBank` (existing disabled when there are no sets): new → name field prefilled with `defaultScanBankName(today, mode)`; existing → chips of all sets, default selection = first set that already contains scanned words, else first set. Primary `save(includedCount)` disabled when no row is included **and** has non-blank word and meaning.
* **saved**: green check, `savedTitle`, `savedText(count, name)`, primary `startStudy` (→ replace with Study tab), secondary `scanAnother` (→ start).

Parser: **port `src/lib/scanParser.ts` 1:1 and use `src/lib/scanParser.test.ts` as the acceptance suite** (10 cases: same-line pairs, numbering/brackets/full-width, two-column tables, meaning under word, merged pairs, ignoring example sentences, dropping meaningless words & duplicates, multiple POS & alternate spellings, no stealing). Summary of behavior:
1. Normalize each line: full-width `！`–`～` → half-width except `；，：（）`; ideographic space → space; trim; drop empty; sort by `y`, then `x`.
2. Per line: strip leading numbering (`1.`, `(1)`, `①`…`⑳`, bullets `•·・-*`); split into alternating Latin/CJK runs (CJK = `㐀-䶿 一-鿿 豈-﫿`; non-letters stick to the previous run; Latin right after a CJK `（`/`(` stays in the CJK run). Each Latin run followed by a CJK run → a pair `{headword, meaning}`; a line that is a single Latin run → a pending headword; a line that is a single CJK run → meaning-only.
3. Headword parse: remove brackets; strip leading non-letters and trailing chars other than letters `'’./-`; peel trailing POS tokens (`n v vt vi a adj ad adv prep conj pron phr num int interj art aux`, combinations split by `/.,&`) into `partOfSpeech` joined ` / `; `a/b` spellings keep the first; reject sentence-like runs (≥2 tokens ending in `.?!` optionally followed by a quote, or ≥3 tokens starting uppercase), > 4 tokens, tokens not `^[A-Za-z][A-Za-z'’-]*$`, or no token ≥ 2 letters. Meaning cleanup: trim leading/trailing separators `\s:=-–—,，.。、` and collapse spaces.
4. Pending headwords pair with the nearest unused meaning-only line on the same row to the right (|center Δ| ≤ 0.6 × max height, x greater; nearest by horizontal gap) or else directly below (gap between −0.3 h and 1.6 h with h = max(source height, 0.005), |Δx| ≤ 0.15; smallest gap), and only if this headword is the closest pending headword claiming that meaning (prevents a word above stealing the meaning of the word below).
5. Drop pairs with empty meaning; dedupe by lowercase word (first wins); key = `"<index>-<lowercase word>"`.
6. Pasted text: each non-empty line becomes a synthetic line `{x: 0.05, y: 0.02 + i×0.035, width: 0.9, height: 0.03}`.

### 5.5 `buildScannedWords(rows, coreWords, stamp = Date.now() base36)` and saving

```
for (index, row) in rows:
  word = row.word.trimmed with whitespace runs collapsed; meaning = row.meaningZh.trimmed
  skip if word or meaning empty, or lowercase word already seen in this batch
  core = core word with same lowercase spelling (if any)
  slug = lowercase word, non [a-z0-9] runs -> "-", trim "-" (fallback "word")
  WordEntry { id: "scan-\(slug)-\(stamp)-\(index)", group: "Scan", word, meaningZh: meaning,
              partOfSpeech: row.partOfSpeech.trimmed || core?.partOfSpeech || "",
              pronunciation: core?.pronunciation ?? "", example: core?.example ?? "", exampleZh: core?.exampleZh ?? "",
              supplementalMeaningZh: "" }
```
The printed meaning always wins; pronunciation/example are borrowed from the built-in word when it exists, otherwise empty (UI hides empty examples).

Save (`saveScannedWords(rows, target)`):
1. Target new → `createCustomSet(name.trimmed || defaultScanBankName(now, mode))`; existing → that set (missing → fail, return nil).
2. Skip rows whose lowercase word is already in the target set's words (re-scanning the same sheet doesn't duplicate).
3. Build scanned words; add them in **reverse** order with `addCustomWordToSet` so the set lists them in printed order.
4. Select that set, make it the **active bank**, message `scanSaved(count, setName)`, return the set id → screen shows `saved`.

Scanned words live only in `customSetState.customWords` (ids `scan-…`), are excluded from the core bank, but are part of `allWords` (lookups, dictionary search, stats). Their progress is tracked like any word by id.

---

## 6. Persistence and first-launch migration

### 6.1 How the RN app stores data

* Library: `@react-native-async-storage/async-storage` **2.2.0** (no `expo-sqlite`/kv-store is used anywhere).
* All app keys start with `word7000-`. At boot the app loads every `word7000-` key into an in-memory cache (other keys, e.g. the Supabase session, are read by supabase-js directly from AsyncStorage). Writes update the cache synchronously and are persisted asynchronously, serialized per key. Progress writes are debounced 300 ms (650 ms in Low Power / Reduce Motion) and flushed when the app leaves the foreground.
* Every value is a UTF-8 string (JSON for objects; plain strings for flags).

### 6.2 Physical location on iOS (verified in `node_modules/@react-native-async-storage/async-storage/ios/RNCAsyncStorage.mm` v2.2.0)

```
<App sandbox>/Library/Application Support/com.rio.word7000/RCTAsyncLocalStorage_V1/
    manifest.json                       ← JSON object { "<key>": "<value string>" | null, ... }
    <md5(key) as 32 lowercase hex chars> ← one file per LARGE value (UTF-8 text, the raw value)
```
* Directory = `NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask)[0]` + `/<CFBundleIdentifier>` + `/RCTAsyncLocalStorage_V1` (constant `RCTStorageDirectory`).
* `manifest.json` (`RCTManifestFileName`) is a single JSON dictionary written atomically, UTF-8. A value whose `NSString.length` (UTF-16 code units) is **≤ 1024** (`RCTInlineValueThreshold`) is stored **inline** as the dictionary value. A longer value is written to a separate file named `RCTMD5Hash(key)` — MD5 of the key's UTF-8 bytes, formatted `%02x` ×16 (lowercase hex, no extension) — in the same directory, and the manifest value for that key is JSON `null`.
* So small prefs (`word7000-theme-v1`, study mode, sort, flags, device id, filter prefs) are inline in `manifest.json`; progress, custom sets, outbox, pending-upgrade, developer vocabulary and the Supabase session are usually separate MD5-named files.
* The directory is marked `NSURLIsExcludedFromBackupKey = YES` (default; the app does not set `RCTAsyncStorageExcludeFromBackup`), so this data is **not** in iCloud device backups.
* Legacy locations (already migrated by the RN library on any run of 1.x builds, but check as fallbacks in this order if the V1 dir is missing): `Documents/RCTAsyncLocalStorage_V1`, `Documents/RNCAsyncLocalStorage_V1`, `Documents/RCTAsyncLocalStorage` (Expo legacy). Same manifest/MD5 format.

Swift reader sketch:
```swift
import CryptoKit
func readAsyncStorage() -> [String: String] {
    let fm = FileManager.default
    let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier!)           // "com.rio.word7000"
        .appendingPathComponent("RCTAsyncLocalStorage_V1")
    guard let data = try? Data(contentsOf: base.appendingPathComponent("manifest.json")),
          let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    var out: [String: String] = [:]
    for (key, value) in manifest {
        if let s = value as? String { out[key] = s; continue }            // inline
        let name = Insecure.MD5.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        if let s = try? String(contentsOf: base.appendingPathComponent(name), encoding: .utf8) { out[key] = s }
    }
    return out
}
```

### 6.3 Every key (all `-v1`; there are no in-place schema migrations yet)

`<uid>` = Supabase user UUID (anonymous or permanent). "Unscoped" keys belong to the pre-account / local-only guest.

| Key | Value | Notes |
|---|---|---|
| `word7000-progress-v1` | `ProgressState` JSON (§3.1) | Unscoped guest/local progress. Removed after it has been merged into an anonymous account and saved to the cloud. Still used when Supabase is not configured. |
| `word7000-progress-v1:user:<uid>` | `ProgressState` JSON | Per-account progress cache (guest UUIDs and permanent accounts). **The main data to migrate.** |
| `word7000-custom-sets-v1` | `CustomSetState` JSON (§5.2) | Unscoped; same lifecycle as unscoped progress. |
| `word7000-custom-sets-v1:user:<uid>` | `CustomSetState` JSON | Per-account sets + custom/scanned words. |
| `word7000-sync-outbox-v1:user:<uid>` | `{"version":1,"queuedAt":ISO,"dirty":{"progress":bool,"customSets":bool},"progress":ProgressState,"customSets":CustomSetState}` | Unsynced cloud write. Must be merged and pushed on first native launch. Invalid → ignored. |
| `word7000-pending-account-upgrade-v1` | `{"createdAt":ISO,"sourceUserId":string\|null,"progress":ProgressState,"customSets":CustomSetState}` | Snapshot taken right before any sign-in attempt; merged into the next **permanent** account activation, cleared after a successful cloud save. |
| `word7000-filter-preferences-v1` | `{"library":{"filter","initial","level","sort"},"quiz":{"filter","initial","level","questionCount":10\|20\|50},"study":{"filter","initial","level"}}` | filter ∈ all/favorites/review/mastered/new; sort ∈ default/alphabetical; any invalid part → all defaults: library `{all, all, all, alphabetical}`, quiz `{all, all, all, 10}`, study `{all, all, all}`. Saved on every change. |
| `word7000-theme-v1` | `system` \| `light` \| `dark` | Missing/other → `system`. |
| `word7000-study-mode-v1` | `english` \| `chinese` | Missing/other → `english`. |
| `word7000-custom-set-sort-v1` | `recent` \| `name` \| `manual` | Default `recent`. |
| `word7000-active-bank-v1` | `core` or a set id | Default `core`. |
| `word7000-streak-reminder-v1` | `true` \| `false` | Anything except `false` = enabled (default on). |
| `word7000-streak-device-id-v1` | e.g. `ios-mgk3x2a1-k2j3h4g5f6` (`ios-` + `Date.now().toString(36)` + `-` + 10 base36 chars) | Created on first run. Used as Live Activity `device_id` and analytics `sourceId`. **Keep it.** |
| `word7000-account-protection-prompt-v1` | `seen` | §3.12. |
| `word7000-permanent-account-used-v1` | `yes` | Set once any non-anonymous user activates; afterwards Google sign-in no longer tries to link the guest identity. |
| `word7000-developer-vocabulary-v1` | `{"importedAt":ISO,"summary":string,"words":[WordEntry]}` | Developer preview vocabulary (rare on iOS since import is unsupported there). |
| `word7000-version-v1` | web build version string | **Web only — ignore.** |
| `word7000-install-guide-v1-installed`, `word7000-install-guide-v1-browser` | `seen` | **Web only — ignore.** |
| `sb-<projectRef>-auth-token` (e.g. `sb-byyaepkhxexppjrdhcaw-auth-token`) | supabase-js session JSON: `{access_token, token_type, expires_in, expires_at, refresh_token, user:{id, is_anonymous, email, user_metadata, …}}` | Written by supabase-js (default storage key `sb-<first label of the Supabase host>-auth-token`). Use its `refresh_token` to keep the user signed in — critical for **guest** users whose cloud data is tied to an anonymous UUID. (`…-code-verifier` only exists for PKCE; the app uses the implicit flow.) |

Values written by native code must keep **the same JSON shapes**, because the same `ProgressState`/`CustomSetState` JSON is uploaded to Supabase and read by any remaining RN/web clients.

### 6.4 First-launch migration algorithm (native)

1. If the new store has `migration.asyncStorage = done` → skip.
2. `old = readAsyncStorage()` (§6.2, with legacy-dir fallbacks). Empty → fresh install; mark done.
3. Copy every `word7000-*` key verbatim into the native key-value store (recommended: keep the exact key names and raw JSON in a small SQLite/`kv` table or one JSON file in Application Support; or decode into models but re-encode losslessly). Do not import web-only keys.
4. Session: if `sb-*-auth-token` exists, decode it and call `supabase.auth.setSession(accessToken:refreshToken:)` (or `refreshSession(refreshToken:)`). Record `user.id` and `user.is_anonymous`.
   * If restoring fails (refresh token revoked/expired), fall back to the normal bootstrap (§7.3) which creates a new anonymous user; then additionally merge the old `word7000-progress-v1:user:<oldUid>` and `custom-sets…:user:<oldUid>` (and its outbox) into the new identity **only if the old user was anonymous** (a permanent account will get its data back from the cloud on re-sign-in).
5. Run the normal activation merge (§7.3/§7.5) — it already merges outbox + pending-upgrade + unscoped legacy data, then saves to the cloud.
6. Leave the old AsyncStorage directory untouched (cheap rollback; App Store downgrades are impossible but TestFlight testers may reinstall old builds). Mark done.
7. Unit-test with fixture directories containing inline and MD5-file values, `null` manifest entries whose file is missing, invalid JSON, and multiple `:user:` scopes.

---

## 7. Accounts & sync (Supabase)

### 7.1 Configuration

* RN reads `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (fallback `EXPO_PUBLIC_SUPABASE_ANON_KEY`), inlined at build time from the **EAS "production" environment variables** (not in the repo; `.env.example` is empty). The web build injects the same values as `globalThis.__WORD7000_CONFIG__ = {supabaseUrl, supabaseAnonKey}` (runtime override, web only). The project ref in docs is `byyaepkhxexppjrdhcaw` → URL presumably `https://byyaepkhxexppjrdhcaw.supabase.co` (confirm with `eas env:list --environment production`).
* URL normalization: trim, strip trailing `/`s and a trailing `/rest/v1`.
* Native: put `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in an `.xcconfig` → Info.plist; the publishable key is public by design. **Never** ship the service-role key.
* If URL or key is missing → "not configured": everything works locally under the unscoped keys, account card shows `accountUnavailableTitle/Text`, status `local`, message `本機記憶中`, gated features show `帳號服務目前無法使用` and do nothing.
* Client: persist session, auto-refresh while foregrounded (stop refresh in background, restart on active), no URL session detection. supabase-js uses the **implicit** OAuth flow; supabase-swift defaults to PKCE — either works because the callback handler accepts both `?code=` and `#access_token=…&refresh_token=…` (§7.4). Hosted Auth (`supabase/config.toml`): site URL `https://word7000-app.rio10255254.workers.dev`, anonymous sign-ins enabled (rate limit 10/h/IP), manual linking enabled, email confirmations on, OTP length 8, Apple provider client id `com.rio.word7000`. Redirect allow list must contain `https://word7000-app.rio10255254.workers.dev/*` (and `word7000://auth/callback`).

### 7.2 Backend objects used by the app

| Object | Columns / signature | App usage |
|---|---|---|
| `public.profiles` | `id uuid PK → auth.users ON DELETE CASCADE`, `progress jsonb NOT NULL DEFAULT '{}'`, `custom_sets jsonb NOT NULL DEFAULT '{"sets":[],"customWords":[]}'`, `updated_at timestamptz` | `select progress, custom_sets where id = uid` (`maybeSingle`); `upsert {id, progress?, custom_sets?, updated_at: now ISO}`. RLS: owner-only select/insert/update/delete. If an error message matches `/custom_sets\|column/i` the app retries with `progress` only (old schema). |
| `public.daily_active_users` | PK `(user_id, activity_date date)`, `account_type` (`guest`/`registered`, set by trigger from `auth.users.is_anonymous` — client cannot choose), `first_seen_at`, `last_seen_at` | Heartbeat upsert `{user_id, activity_date: local YYYY-MM-DD, last_seen_at: now}` `onConflict: user_id,activity_date` (§7.11). Owner-only RLS. View `word7000_private.daily_metrics` is admin-only. |
| `public.live_activity_devices` | PK `(user_id, device_id)`; `push_to_start_token text NOT NULL`, `activity_push_token`, `enabled bool`, `app_locale ('zh-TW'\|'en')`, `time_zone` (IANA, default `Asia/Taipei`), `streak`, `daily_target (>0)`, `studied_today (≥0)`, `progress_date date`, `streak_expires_at`, `activity_started_for_expires_at`, `noon_activity_started_for_local_date`, `noon_activity_expires_at`, `last_push_error`, `updated_at` | §8.3 upsert / disable. Owner-only RLS. |
| RPC `claim_due_streak_live_activities()`, `claim_due_noon_live_activities()` | security definer, **service_role only** | Called by the edge function, not the app. |
| Edge function `delete-account` (JWT verified) | `POST {}` with the user's bearer token → `auth.admin.deleteUser(uid)` → `{deleted: true}` or `{error}` | §7.7. |
| Edge function `send-streak-live-activities` (no JWT; header `x-cron-secret`) | cron every minute | §8.4. |

There are no other tables, storage buckets or RPCs used by the client. (`deleteCloudUserData` in `supabaseProgress.ts` exists but is unused.)

### 7.3 Identity lifecycle & bootstrap

```
launch:
  progress = normalize(load("word7000-progress-v1") ?? initial)        // shown immediately
  if !configured: status=local, message=本機記憶中; done
  status=loading, message=檢查登入狀態
  session = getSession()  (10 s timeout)
  if session.user: user = getUser() (10 s timeout; on failure use session.user) → activate(user)
  else: anon = signInAnonymously() (10 s)
        error → isAnonymous=true, status=local, message=訪客進度保存在這台裝置   (works offline on unscoped keys)
        ok    → activate(anon.user)
  any thrown error/timeout → status=error, isAnonymous=true, message = error text or 登入狀態檢查失敗
```

`activate(user, fallbackEmail?)` — the single place where local and cloud data meet:
```
anonymous = user.is_anonymous == true
if !anonymous: set word7000-permanent-account-used-v1 = yes
cloud      = load profiles row for user.id (12 s timeout; on timeout treat as not found)
userLocal  = load "word7000-progress-v1:user:<id>"
outbox     = load "word7000-sync-outbox-v1:user:<id>"
pending    = anonymous ? nil : load "word7000-pending-account-upgrade-v1"
legacyGuest= anonymous ? load "word7000-progress-v1" (unscoped) : nil
progress   = normalize(mergeProgressStates(cloud.progress, userLocal, outbox.progress, legacyGuest, pending.progress), today)
customSets = mergeCustomSetStates(cloud.customSets, load sets ":user:<id>", anonymous ? load unscoped sets : nil, outbox.customSets, pending.customSets)
save both under ":user:<id>"; set in memory; clear selected set, study session and set picker
account = {userId, isAnonymous, userEmail: anonymous ? nil : user.email ?? fallbackEmail, userName: anonymous ? nil : metadata name,
           busy=false, status = anonymous ? guest : syncing, message = anonymous ? 訪客進度已自動保存 : 已登入，正在背景同步}
async: saveCloudUserMemory(progress, customSets) (15 s timeout) → profiles upsert {id, progress, custom_sets, updated_at}
   ok:  clear outbox; if anonymous → delete unscoped progress & sets keys
        else → delete pending-upgrade; if pending.sourceUserId != nil && != user.id → delete that user's progress, sets and outbox keys
        status = anonymous ? guest : signedIn; message = anonymous ? 訪客進度已自動保存 : (cloud.found ? 已登入並同步 : 已建立新的帳號記憶)
   fail: status = error; message = 進度已保存在本機，稍後會自動重試同步
if !anonymous: dismiss the upgrade sheet (220 ms) and run the action that triggered it (e.g. favorite the word, open sets)
```
The account's `userId` change also (re)creates the sync queue (restoring any outbox → immediate flush), the progress writer (key now user-scoped), the Live Activity registration queue and the heartbeat.

`stageAccountUpgrade()` (called right before Google/Apple/email sign-in/sign-up): save `{progress, customSets, sourceUserId: current userId (may be anon uid or nil), createdAt}` to `word7000-pending-account-upgrade-v1`. This is how a guest's progress is carried into a different (existing) permanent account.

### 7.4 Auth methods

**Guest (anonymous)** — automatic, see bootstrap. A guest is a real Supabase user (`is_anonymous = true`) whose data syncs to `profiles` like anyone else's; the UI treats guests as "not signed in" (§7.6).

**Google** (`handleGoogleSignIn`):
1. `stageAccountUpgrade()`.
2. `link = isAnonymous && userId != nil && word7000-permanent-account-used-v1 != yes` (native only).
3. status loading, message `正在開啟 Google 登入`.
4. Get the provider URL: `link ? auth.linkIdentity(provider: .google, …)` (GET `/auth/v1/user/identities/authorize?provider=google&skip_http_redirect=true&redirect_to=…` with the user's JWT) : `auth.signInWithOAuth(provider: .google)`; options: `redirectTo = https://word7000-app.rio10255254.workers.dev/auth-native.html`, `skipBrowserRedirect = true`, query param `prompt=select_account`.
   * On link error that is "identity already exists" (`code == identity_already_exists` or message `/already (linked|registered)|identity.*another user/i`) → restart step 4 with `link = false`. Other error → status error, message = error text.
5. Open `ASWebAuthenticationSession(url, callbackURLScheme: "word7000")`. The hosted `auth-native.html` page immediately redirects to `word7000://auth/callback` + the original `?query` + `#fragment` (and shows an "Open Word7000" button as fallback). Cancel → status `guest`/`signedOut`, message `已取消登入`.
6. Parse the callback: params from query and fragment combined: `access_token`, `refresh_token`, `code`, `error_description ?? error`, `error_code`, `identity_id`.
   * Link flow: error with `error_code == identity_already_exists` or `/already.*(linked|registered)/i` → redo as plain sign-in; other error → status error (`callback.error` or `Google 帳號連結失敗`). Success → `refreshSession()` then `getUser()`; user must be non-anonymous (else error `Google 帳號連結未完成`) → `activate(user)`.
   * Sign-in flow: error → status (`guest` if anonymous else `error`), message = error or `登入導回失敗`; `code` → `exchangeCodeForSession(code)`; tokens → `setSession(access, refresh)`; neither → error `登入導回沒有取得帳號資料`; success → `activate(user)`.
   (With supabase-swift you can use `signInWithOAuth(provider:redirectTo:launchFlow:)` / `linkIdentity(provider:)` that wrap ASWebAuthenticationSession, but keep `redirectTo` = the hosted bridge page, which is the allow-listed redirect.)

**Apple** (`handleAppleSignIn`, iOS only):
1. `stageAccountUpgrade()`; status loading, message `正在開啟 Apple 登入`.
2. Raw nonce = 32 chars drawn uniformly from `0-9A-Za-z-._` via `SecRandomCopyBytes` (byte % 65); hashed nonce = lowercase hex SHA-256 of the raw nonce.
3. `ASAuthorizationAppleIDRequest` scopes `[.email, .fullName]`, `nonce = sha256`, `state = raw`.
4. Require `identityToken` (else `Apple 登入沒有回傳帳號憑證`) and `authorizationCode` (else `Apple 登入沒有回傳授權碼`). Check `getCredentialState(forUserID:)`; if it is known and not `.authorized` → `Apple 帳號授權狀態無效，請重新登入`.
5. Credentials `{provider: apple, idToken: identityToken, nonce: raw, accessToken: authorizationCode}`.
   * If currently anonymous with a user id: **link** = POST `/auth/v1/token?grant_type=id_token` with body `{provider, id_token, access_token, nonce, link_identity: true}` and the guest's bearer JWT (supabase-swift: `linkIdentityWithIdToken`). If the error is "already linked" → `signInWithIdToken(credentials)`. Other error → status error with its message. Success → `getUser()`.
   * Otherwise `signInWithIdToken(credentials)`.
6. No user → status error (`Apple 登入失敗` or the error text).
7. Update user metadata (best effort) with `{apple_user: credential.user, email, given_name, family_name, full_name: "given family"}` (only non-empty fields; Apple only returns name/email on first authorization).
8. `activate(user, fallbackEmail: credential.email)`.
9. User cancel (`ASAuthorizationError.canceled`) → status guest/signedOut, message `已取消登入`.

**Email/password** (fallback):
* Sign up: requires email and password ≥ 6 chars (else `Email 和密碼至少 6 碼`); message `建立帳號中`; `stageAccountUpgrade()`; `auth.signUp(email, password)`; if a session is returned → activate; else status guest/signedOut, message `請確認信箱後登入` (confirmations are enabled).
* Sign in: requires both (else `請輸入 Email 和密碼`); message `登入中`; stage; `signInWithPassword`; error → `登入失敗`/error text; success → activate.
* Email accounts are never linked to the guest identity; guest data moves via the pending-upgrade snapshot.

### 7.5 Merge and conflict rules (port `mergeProgressStates`, `mergeCustomSetStates`, `mergeLearningAnalyticsStates` 1:1; tests in `progress.test.ts`, `customSets.test.ts`)

Progress — `mergeProgressStates(s1, s2, …)` (nil inputs skipped; none → `{dailyTarget: 20, streak: 0, studiedToday: 0, words: {}}`):
* **Daily fields** (`dailyTarget`, `streak`, `studiedToday`, `dailyProgressDate`, `lastStudyDate`) all come from ONE source: the state with the greatest `dailyProgressDate ?? lastStudyDate ?? ""`; tie → greater `studiedToday`; tie → earlier argument wins.
* **Words**: union by id; for an id present in several states, fold left with `mergeWordProgress(a, b)`:
  * status source = `b` if `(b.statusUpdatedAt ?? b.lastStudied ?? "") > (a.statusUpdatedAt ?? a.lastStudied ?? "")` else `a` → gives `status`, `difficult`, `statusUpdatedAt`, `dueDate` (if set), `stage` (if set).
  * favorite source = `b` if `(b.favoriteUpdatedAt ?? b.favoritedAt ?? "") > (a's)` else `a` → `favorite`, `favoriteUpdatedAt`, `favoritedAt` (only if favorite).
  * `lastStudied` = max of both; `reviewCount` = max; `lapses` = max (only if either has it).
  * Note: unknown fields are dropped by this merge in RN; keep that behavior or preserve extras deliberately.
* **Analytics**: per date, per source id, per counter = max; `bestStreak` = max; `version: 1`.
* Activation then runs `normalizeProgressForDate`.

Custom sets — `mergeCustomSetStates(s1, s2, …)`:
* Tombstones: union, keep the latest `deletedAt` per id (string compare).
* `customWords`: concatenated in argument order, dedupe by `"<id>:<lowercase word>"` (first wins).
* Sets: skip any set with a tombstone where `deletedAt >= set.updatedAt`; same id → the later argument wins if `Date(updatedAt) >= Date(existing.updatedAt)` (so ties go to later arguments: cloud < user-local < guest-local < outbox < pending); first-seen position is kept.

Cloud writes are **whole-document overwrites** (`profiles.progress` / `custom_sets` JSON replaced). Cloud is only **read** at activation (launch, sign-in, sign-out → new guest, delete → new guest). There is no pull on foreground and no realtime subscription — two devices used alternately converge only when one relaunches. Keep this behavior for parity (optionally improve later with a pull-merge on foreground; the merge functions make that safe).

### 7.6 Permanent-account gating

`isPermanentAccount = userId != nil && !isAnonymous`. Guests and local-only users can study, quiz, search, use filters except Favorites, view stats, change settings, and delete their (guest) account. These need a permanent account (`requestAccountUpgrade(reason, then)`):

| Reason | Triggered by |
|---|---|
| `favorites` | favorite star anywhere; Favorites status filter (study, quiz, library); Profile "saved words" tile |
| `customSets` | add-to-set anywhere; library Manage / set chips; library Scan; bank picker: choosing a set, Scan, Manage; opening `sets` / `scan` routes; importing a custom CSV |
| `dataTools` | developer export / import |
| `protectProgress` | automatic nudge (§3.12) |

`requestAccountUpgrade`: permanent → run `then` immediately. Not configured → message `帳號服務目前無法使用`, nothing else. Otherwise remember `then` and present the **upgrade sheet**: drag handle, icon tile (star orange for favorites / books for customSets / database for dataTools / shield for protectProgress), close ✕ (a11y `later`), title `title[reason]`, body `body[reason]`, green cloud capsule `badge[reason]`, buttons `appleSignIn` (dark `#101722`, full width) and `googleSignIn` (secondary), caption `privacy`, text button `later`. Animation: spring (damping 25, mass 0.86, stiffness 225, no overshoot) from y 30 / scale 0.975; Medium haptic 45 ms after showing; dismiss 270 ms. Dismissal disabled while busy. On successful permanent activation the sheet closes and `then` runs.

### 7.7 Account deletion

1. Settings row → native alert (`deleteAccountDataConfirmTitle`, `deleteAccountDataConfirmText`, `deleteAccountDataConfirmCancel` (cancel style), `deleteAccountDataConfirmAction` (destructive)). If there is no user id the RN code skips the alert and shows `請先登入` (row is disabled anyway).
2. busy, status loading, message `正在刪除帳號與資料`.
3. `functions.invoke("delete-account", method: POST, body: {})` with the current session JWT. Error or `{error: string}` → status error, message = error. The function deletes the auth user; `profiles`, `daily_active_users`, `live_activity_devices` rows cascade.
4. Locally remove `word7000-progress-v1:user:<uid>`, `word7000-custom-sets-v1:user:<uid>`, `word7000-sync-outbox-v1:user:<uid>`; `auth.signOut(scope: .local)`.
5. Reload unscoped (guest) progress and sets, clear session state; message `帳號已刪除，正在建立訪客進度`; `signInAnonymously()` → `activate` (new guest) or on failure status local, message `帳號已刪除，訪客進度保存在這台裝置`.
(Also end any running Live Activity — the RN app doesn't explicitly, but the plan recomputes from the new progress.)

### 7.8 Account state model

```
AccountState { configured: Bool; email: String; password: String   // form fields
               isAnonymous: Bool; userId: UUID?; userEmail: String?; userName: String?
               busy: Bool; status: local|loading|guest|signedOut|signedIn|syncing|saved|error; message: String }
initial: configured ? {isAnonymous: true, status: loading, message: 正在準備訪客進度} : {status: local, message: 本機記憶中}
```
The Profile status capsule shows `message` (red when `status == error`). All sign-in buttons are disabled while `busy` or not configured.

### 7.9 Sign-out

1. Save current progress/sets locally under the user key; enqueue a full sync (both dirty) and **await** the flush (or a direct `saveCloudUserMemory`, clearing the outbox on success).
2. Disable this device's Live Activity registration: `update live_activity_devices set enabled=false, updated_at=now where user_id=uid and device_id=<device id>`.
3. `auth.signOut()`.
4. Load unscoped progress/sets, clear session/picker state, account → `{isAnonymous: true, userId: nil, …, status: loading, message: 正在切換為訪客模式}`.
5. `signInAnonymously()` → `activate(newGuest)` (which also absorbs the unscoped data); failure → status local, message `已登出，訪客進度保存在這台裝置`.

### 7.10 Background sync queue (`UserMemorySyncQueue`, port `src/lib/userMemorySync.ts`)

* Exists while `userId != nil` (one per user). On creation `restore()` loads the outbox key; if present → status pending, flush immediately.
* Every progress change (after initial load) → `enqueue({progress, customSets}, {progress: true})`; every custom-set change → `{customSets: true}`. Pending batch keeps the newest snapshot and ORs the dirty flags.
* Persist the pending batch to `word7000-sync-outbox-v1:user:<uid>` 250 ms after the last enqueue (and immediately before a flush / on dispose).
* Flush 900 ms after the last enqueue, on every app-state change (foreground and background), and on sign-out.
* Flush: one in flight at a time; send `saveAll` (upsert progress + custom_sets) if both dirty, else only the dirty column; on success clear the outbox (unless newer work arrived → reschedule) and set status saved; on failure merge back into pending (newest snapshot, OR'ed flags), persist, status error, retry after `min(3000 × 2^attempt, 300000)` ms.
* Statuses: idle, pending, syncing, saved, error (not surfaced in the RN UI beyond the account message).
* Native: run flushes in a `Task`, request background time (`beginBackgroundTask`) when the app resigns active so the last flush completes.

### 7.11 Daily-active heartbeat

While `userId != nil` (guest or permanent): upsert `daily_active_users` immediately, every 5 minutes, and on every return to foreground, skipping if the last attempt was < 60 s ago or the app is not active. Failures ignored.

---

## 8. Live Activities, widgets, notifications

### 8.1 Inventory

* **One Live Activity**, `StreakLiveActivity` (defined with `expo-widgets` + `@expo/ui` SwiftUI DSL in `src/liveActivity/StreakLiveActivity.tsx`), with two kinds: `streak` (last-hour countdown before the streak breaks) and `noon` (daily 12:00–13:00 study prompt with today's progress).
* Started **locally** by the app (streak kind only, when inside the final hour while the app runs) and **remotely** via APNs push-to-start for both kinds (server cron).
* No Home Screen widgets, no local notifications (`expo-notifications` is not installed), no alert pushes. The setting `streakReminder` controls both kinds.

### 8.2 Local streak plan (`src/lib/streakReminder.ts`)

```
buildStreakReminderPlan(progress, now, enabled):
  if !enabled || progress.streak <= 0 || lastStudyDate == nil → empty (activeNow=false, no dates)
  elapsedDays = days between local midnight of lastStudyDate and local midnight of now
  if elapsedDays < 0 || > 1 → empty
  expiresAt = local midnight of (lastStudyDate + 2 days)   // i.e. end of the day after the last study day
  startsAt  = expiresAt − 1 h
  activeNow = startsAt <= now < expiresAt
```
* A clock timer fires at the earliest future of `{startsAt, expiresAt, next local midnight}` (+250 ms, min 1 s) and on every return to foreground; it updates "now", rolls the current date (→ `normalizeProgressForDate`), and re-evaluates.
* `syncStreakLiveActivity(props, activeNow)`: if `props == nil || !activeNow || now >= expiresAt` → end all running instances immediately; else update the first running instance with the new props or start one (deep link `word7000://study`), end duplicates, and read its activity push token. Result `{active, activityPushToken, startedForExpiresAt: expiresAt ISO}`.
* Local props (zh UI / English UI):

| Prop | zh-TW UI (`english` mode) | English UI (`chinese` mode) |
|---|---|---|
| `activityKind` | `streak` | `streak` |
| `title` | `你的連勝快中斷了` | `Your streak needs you` |
| `keepStreakLabel` | `完成 1 個單字即可保住連勝` | `Study 1 word to keep it` |
| `streakLabel` | `連勝 {n} 天` | `{n}-day streak` |
| `countdownLabel` | `剩餘時間` | `Time left` |
| `startedAt` / `expiresAt` | ms epoch of plan | |
| `streak`, `progressCurrent: 0`, `progressTarget: 1` | | |

### 8.3 Device registration (for server-started activities)

* Observe `Activity<LiveActivityAttributes>.pushToStartTokenUpdates` (iOS 17.2+; also read the current `pushToStartToken`), hex-encode lowercase (`%02x`).
* While signed in (any `userId`) and a push-to-start token exists, enqueue (8 s debounce, dedupe identical payloads, retry after 60 s on failure, flush on background) an upsert into `live_activity_devices` `onConflict (user_id, device_id)`:
  ```
  { user_id, device_id: <word7000-streak-device-id-v1>, push_to_start_token,
    activity_push_token: (local activity's expiry == plan.expiresAt) ? its push token : null,
    activity_started_for_expires_at: same condition ? expiresAt ISO : null,
    enabled: streakReminderEnabled, app_locale: studyMode == chinese ? "en" : "zh-TW",
    time_zone: TimeZone.current.identifier (fallback "UTC"),
    streak: plan.streak, streak_expires_at: plan.expiresAt ISO or null,
    daily_target: max(1, round(dailyTarget)), studied_today: max(0, round(studiedToday)),
    progress_date: <local today YYYY-MM-DD>, updated_at: now ISO }
  ```
  Re-enqueue whenever any of these inputs change. Sign-out sets `enabled = false` for this device.

### 8.4 Server (`supabase/functions/send-streak-live-activities`, unchanged by the port)

Runs every minute (`x-cron-secret`). Claims (atomically, deduping devices that share a push-to-start token, newest `updated_at` wins):
* **streak**: `enabled AND streak > 0 AND now < streak_expires_at <= now + 1 h AND activity_started_for_expires_at IS DISTINCT FROM streak_expires_at` → sets `activity_started_for_expires_at = streak_expires_at` (so a device that already started the activity locally and registered it is skipped).
* **noon**: `enabled AND local time (device time_zone) in [12:00, 13:00) AND noon_activity_started_for_local_date IS DISTINCT FROM local date` → sets that date and `noon_activity_expires_at = next local midnight`.

Sends APNs (`https://api.push.apple.com` unless `APNS_ENVIRONMENT=sandbox`) `POST /3/device/<push_to_start_token>`, headers `apns-push-type: liveactivity`, `apns-topic: com.rio.word7000.push-type.liveactivity`, `apns-priority: 10`, `apns-expiration: expiresAt s`, ES256 JWT. Payload:
```json
{ "aps": { "event": "start", "timestamp": <now s>, "stale-date": <expiresAt s>, "input-push-token": 1,
           "alert": { "title": "<props.title>", "body": "<props.keepStreakLabel>" },
           "attributes-type": "LiveActivityAttributes", "attributes": {},
           "content-state": { "name": "StreakLiveActivity", "props": "<JSON string of props>" } } }
```
Server props: streak kind same strings as §8.2 (startedAt = expiresAt − 1 h). Noon kind (`studied = progress_date == noon local date ? studied_today : 0`, `remaining = max(1, daily_target) − studied`):

| Prop | zh-TW (`app_locale = zh-TW`) | en |
|---|---|---|
| `title` | `中午學習時間` | `Your noon study break` |
| `keepStreakLabel` | remaining > 0: `再學 {remaining} 個單字，完成今天目標`; else `今日目標已完成，複習 1 個單字保持手感` | `Study {remaining} more words to reach today's goal` / `Goal complete. Review 1 word to stay sharp` |
| `streakLabel` | streak > 0: `連勝 {n} 天`; else `今天開始連勝` | `{n}-day streak` / `Start your streak today` |
| `countdownLabel` | `今日進度` | `Today` |
| `progressCurrent` / `progressTarget` | studied / max(1, daily_target) | |
| `startedAt` / `expiresAt` | now / next local midnight (ms) | |

On APNs failure the claim columns are reset and `last_push_error` stored, so the next minute retries.

### 8.5 Native implementation requirements

* Widget extension with an `ActivityConfiguration(for: LiveActivityAttributes.self)` where
  ```swift
  struct LiveActivityAttributes: ActivityAttributes {
      var url: String?                                   // server sends attributes {} → nil
      struct ContentState: Codable, Hashable { var name: String; var props: String }   // props = JSON string
  }
  ```
  Decode `props` into `StreakLiveActivityProps { activityKind: "noon"|"streak"?, countdownLabel, expiresAt (ms), keepStreakLabel, progressCurrent?, progressTarget?, startedAt (ms), streak, streakLabel, title }`. Keep these exact names or the server-started activities will fail to decode.
* Main app Info.plist: `NSSupportsLiveActivities = YES`, `NSSupportsLiveActivitiesFrequentUpdates = NO`; push entitlement `aps-environment` (production for release); request activities with `pushType: .token`. App Group `group.com.rio.word7000` was configured for the extension (not used for any data the port needs).
* Tap target: `word7000://study` → open the Study tab (local activity sets it as the attributes `url` / `widgetURL`; server-started ones have no URL → default app launch).
* ActivityKit availability: iOS 16.1+ for activities, 17.2+ for push-to-start. Deployment target of the RN app is 15.1+ for the scanner pod; choose ≥ iOS 17 for the native app (see risks).

**Layout** (dark, fixed palette; `reduced` = `isLuminanceReduced` / Always-On):
* Colors: streak accent `#FF9F0A` (reduced `#FFD76A`), soft `#3D2A0C`, symbol `flame.fill`; noon accent `#40A9FF` (reduced `#8BD7FF`), soft `#102C42`, symbol `book.closed.fill`; noon completed (remaining 0) accent `#30D158` (reduced `#63E6A1`), soft `#163D2B`, symbol `checkmark.circle.fill`. Primary text `#F5F7FA`, secondary `#AEB5C0` (reduced `#C7C7CC`), tertiary `#7E8795` (reduced `#A1A1A6`), background tint `#101217` (reduced `#0C0D0F`).
* `progressTarget = max(1, target)`, `progressCurrent = clamp(current, 0, target)`, `remaining = target − current`, countdown interval = `startedAt…expiresAt`.
* **Lock Screen banner** (padding 16×14, spacing 12): 42 pt circle (soft) with symbol 21 pt accent; middle column (spacing 5): title 16 bold (1 line, min scale 0.82), keepStreakLabel 12 medium secondary (2 lines), linear progress (noon: value = current/target; streak: counting-down timer progress over the interval) tinted accent, footer row streakLabel 10 semibold accent … `Word7000` 10 medium tertiary; trailing metric (noon: `current/target` rounded 21 bold monospaced digits + countdownLabel 10 semibold tertiary; streak: countdown timer `Text(timerInterval:countsDown:)` rounded 21 bold + countdownLabel in accent).
* **Small banner** (`bannerSmall`, e.g. Watch/CarPlay): symbol 16, title 12 bold + streakLabel 10 secondary, trailing = compactTrailing.
* **Dynamic Island compact leading**: symbol 15 + (noon `W7` / streak number) rounded 12 bold. **Compact trailing**: noon `current/target` or streak countdown, rounded 13 bold accent. **Minimal**: noon — 30 pt soft circle with remaining count or `✓`; streak — countdown rounded 11 bold accent.
* **Expanded**: leading symbol 19 + `W7`/streak number (rounded 15 bold); trailing = metric (19 pt version); center title 15 bold; bottom: keepStreakLabel (12 medium, 2 lines), progress bar, footer streakLabel … small accent capsule 16×4 + `Word7000`.

---

## 9. Theme & visual system

### 9.1 Direction (commit `045bcd4` "Restyle the app in a clean iOS-native look")

* iOS-native, **borderless grouped surfaces**: every card/control has `borderWidth: 0`; white (`#FFFFFF`) / `#1C1C1E` surfaces on a system-gray `#F2F2F7` (light) / pure black `#000000` (dark) page. No shadows on cards (only on overlays). Continuous ("squircle") corners everywhere.
* **SF Rounded** for headings and numbers; SF Pro for body. Tabular digits for counters.
* **SF Symbols** for icons (lucide line icons only as RN fallback).
* Semantic colors: **blue accent** for actions/selection/progress, **green** for known/mastered/correct/goal-done, **orange** for review/streak/favorites, **red** for miss/wrong/destructive, **indigo** for Chinese mode.
* Home leads with a progress ring and one pill start button; study/quiz filters hide behind a small icon next to the bank bar so the card gets the screen; helper subtitles that repeat titles were removed.
* Liquid Glass (iOS 26+, not Low Power, not Reduce Transparency): system tab bar glass with minimize-on-scroll; icon buttons get an interactive glass background (`GlassView`, `regular` style, tint light `rgba(235,245,255,0.62)` / dark `rgba(18,29,43,0.58)`; secondary `rgba(255,255,255,0.68)` / `rgba(44,44,46,0.72)`). In SwiftUI use `.glassEffect(.regular.interactive())` behind `if #available(iOS 26, *)`.

### 9.2 Palette (`src/design/iosVisualSystem.ts`)

| Token | Light | Dark | SwiftUI suggestion |
|---|---|---|---|
| accent | `#007AFF` | `#0A84FF` | `.blue` / `Color.accentColor` |
| accentPressed | `#0066CC` | `#409CFF` | |
| accentSoft | `rgba(0,122,255,0.10)` | `rgba(10,132,255,0.18)` | `.blue.opacity(0.10/0.18)` |
| accentBorder | `rgba(0,122,255,0.24)` | `rgba(10,132,255,0.36)` | |
| background | `#F2F2F7` | `#000000` | `Color(.systemGroupedBackground)` |
| surface | `#FFFFFF` | `#1C1C1E` | `Color(.secondarySystemGroupedBackground)` |
| surfaceSecondary | `#F7FAFF` | `#111A26` | lightly blue-tinted control fill |
| surfaceTertiary | `#EDF5FF` | `#182538` | segmented/track fill |
| label | `#1C1C1E` | `#FFFFFF` | `.primary` |
| labelSecondary | `#6C6C70` | `#AEAEB2` | `.secondary` |
| labelTertiary | `#8E8E93` | `#8E8E93` | `Color(.tertiaryLabel)`-ish |
| separator | `rgba(60,60,67,0.18)` | `rgba(84,84,88,0.65)` | `Color(.separator)` |
| separatorStrong | `rgba(60,60,67,0.29)` | `rgba(99,99,102,0.78)` | |
| fill | `rgba(0,122,255,0.08)` | `rgba(10,132,255,0.18)` | |
| green / greenSoft | `#34C759` / `#EAF9EE` | `#30D158` / `#12351E` | `.green` |
| orange / orangeSoft | `#FF9500` / `#FFF4E5` | `#FF9F0A` / `#3A2608` | `.orange` |
| red / redSoft | `#FF3B30` / `#FFF0EF` | `#FF453A` / `#3A1714` | `.red` |
| indigo / indigoSoft | `#5856D6` / `#F0EFFF` | `#5E5CE6` / `#25244A` | `.indigo` |

Custom-set colors (cycled by creation index): `#007AFF, #34C759, #5856D6, #FF2D55, #FF9500, #00C7BE`.
Controls fill (chips, search field, secondary buttons, quiz options): `rgba(120,120,128,0.12)` light / `0.24` dark (= `Color(.tertiarySystemFill)`-like). Other fixed tints seen: group pill `#EAF4FF` text `#0066CC` (dark `rgba(10,132,255,0.18)` / `#0A84FF`); progress track `#DCEEFF` (dark `#2C2C2E`); example box `#F7FAFF`; quiz correct `#EAF9EE`/dark `#12351E`, wrong `#FFF0EF`/dark `#3A1714`; streak text `#C25E00`; Apple button `#101722`; tertiary chevrons `#C7C7CC`. Contrast tests require label/background ≥ 7:1 and secondary ≥ 4.5:1 on background, surface and surfaceSecondary; accent ≥ 3:1 on surface.

### 9.3 Typography

| Role | Spec |
|---|---|
| Tab header title | 21 bold |
| Hero title (Home) | SF Rounded 24/30 bold (30/36 elsewhere) |
| Ring value / ring target | SF Rounded 32 heavy tabular / 13 semibold tabular |
| Section title | SF Rounded 17 semibold |
| Row title (home action rows) | SF Rounded 15 semibold |
| Stat value / stat label | SF Rounded 22 bold / 12 regular secondary |
| Bank name | SF Rounded 16 bold |
| Study big word | 40/48 bold (Chinese 30/38); pinyin 15 semibold accent; pronunciation 17 secondary |
| Card meaning | 22/30 semibold; POS label 13 semibold accent |
| Example / translation | 15/22 label; 15/23 secondary |
| Library row word / meaning / example | 20 bold (Chinese 17/23) / 15 medium / 13/19 secondary |
| Word detail word | SF Rounded 42/48 bold |
| Card meta / captions | 13 medium secondary |
| Buttons | primary 15 semibold white; grade buttons 15–16 bold |
| Empty title / text | SF Rounded 15 bold / 13 secondary |
| Upgrade sheet title | SF Rounded 26/32 bold |
| Scan title / section | SF Rounded 24 heavy / 17 bold |
| Analytics title / metric | 27 heavy / 22 heavy tabular |

Respect Dynamic Type where practical (RN used fixed sizes).

### 9.4 Shapes and spacing

Page padding 18 (tabs: top 10), stack gap 14 (analytics 16). Cards radius 20, padding 16–18; study card & summary radius 24; list rows & settings rows & quiz options & grade buttons radius 14; primary/secondary buttons radius 12, min height 48–50; Home start button capsule height 52; chips capsule (padding 10×8), letter chips 34 pt; group pills capsule. Progress bars 6 pt capsule.

### 9.5 Motion & haptics

Press feedback per tone (scale / opacity / translateY): primary 0.977/0.95/1, secondary 0.983/0.95/0.75, chip 0.972/0.94/0, icon 0.958/0.92/0, tab 0.975, list 0.992/0.97, libraryItem 0.987/0.965/0.75; press-in 110 ms ease-out, release spring (damping ratio 0.84, 350 ms). Card/list entrance 260 ms (y 12→0, scale 0.985→1; list rows stagger offsets 10+2·min(i,6), first 5 rows only). Haptics on press-in: primary **Heavy**, secondary **Medium**, chip **Light**, icon **selection**, tab **Medium**, list **Light**, libraryItem **Medium**. All motion is reduced / skipped when Reduce Motion or Low Power Mode is on ("conserve resources"); haptics are skipped in Low Power Mode.

### 9.6 Appearance preference

`system | light | dark` (persisted). In Settings, an actual color change plays a full-screen cross-fade (to `#000000` or `#F2F2F7`, 190 ms in, 24 ms hold, 280 ms out); skipped when conserving resources. Native: `.preferredColorScheme(nil | .light | .dark)` at the root.

---

## 10. Update checks and other user-visible behavior

### 10.1 iOS update policy (`public/ios-update.json`)

```json
{ "latestBuild": 25, "minimumBuild": 23, "testFlightUrl": "https://apps.apple.com/app/testflight/id899247664" }
```
* Fetched from `https://word7000-app.rio10255254.workers.dev/ios-update.json?t=<ms>` (`Accept: application/json`, `Cache-Control: no-cache`, 8 s timeout) at launch and on each return to foreground (15-min cooldown), skipped in debug.
* Valid only if both builds are positive integers (number or digit string), `minimumBuild <= latestBuild`, and `testFlightUrl` is `https:` on `apps.apple.com` or `testflight.apple.com`. Invalid/unreachable → ignore.
* Current build = `CFBundleVersion` parsed as a positive integer. `available = current < latestBuild`, `required = current < minimumBuild`.
* **required** → blocking overlay (dim `rgba(28,28,30,0.78)`, white card): cloud icon, `updateTitle`, `testFlightUpdateDetail`, `testFlightUpdateHint`, button `testFlightUpdateButton` → open `testFlightUrl`. No countdown, cannot be dismissed.
* **available** (not required) → Home update row shows `updateAvailable` / `updateAvailableDetail`; tapping it opens the TestFlight URL.
* Home update row states: idle (`updateNow` + `updateCheckDetail`), checking (spinner + `updateChecking`, disabled), current (✓ `updateCurrent` + `updateCurrentDetail`), available (download icon `updateAvailable` + `updateAvailableDetail`), error (retry icon `updateRetry` + `updateCheckFailed`). Manual tap: available → open TestFlight; otherwise re-fetch policy → available ? open TestFlight : `current`.
* **EAS OTA updates (`expo-updates`) do not exist in a native app — drop** the "update downloaded, auto-reload in 6.5 s" overlay (`updateDetail`, `updateCountdown`, `updateNow`) and the OTA part of the manual check.
* When shipping the native build, bump `latestBuild` (and later `minimumBuild`) in `public/ios-update.json` on the web host so RN builds are told to update.

### 10.2 Links

* Privacy: `https://word7000-app.rio10255254.workers.dev/privacy.html`; Support: `…/support.html` (open in Safari / `SFSafariViewController`). Failure → message `無法開啟連結`.
* Base origin can be overridden by `EXPO_PUBLIC_WORD7000_WEB_ORIGIN` (default above).

### 10.3 Deep links

* `word7000://auth/callback…` — OAuth return (handled by `ASWebAuthenticationSession`; if it arrives via `onOpenURL`, route through the same callback parser).
* `word7000://study` — Live Activity tap → Study tab.
* Anything else → Home.

### 10.4 Accessibility

Labels/hints in copy tables (`a11y` keys like `viewWordDetails`, `favoriteWordName`, `addToSetName`, `levelAccessibility`, `includeRow`, …). Study swipe has button equivalents (Show answer / Not yet / I know it). Card front a11y hint `tapToReveal`; swipe hint `"<swipeReviewHint>; <swipeKnownHint>"`. Progress ring exposes a 0–100 progress value.

### 10.5 Web-only features — DROP in the native app

| Feature | Where |
|---|---|
| Add-to-Home-Screen install guide (overlay + Profile "Tutorial" row, `installGuideStepsByMode`, `systemCopy.installGuide`, `word7000-install-guide-v1-*`) | App.tsx |
| Web version polling `/version.json`, auto-reload, `word7000-version-v1` | `useAppUpdateCheck` web branch |
| Service worker registration, PWA manifest | `public/` |
| Keyboard shortcuts on Study (Space/Enter/←/→) | `StudyView` |
| `?ios-preview` web iPhone frame mode | App.tsx |
| Browser file download/upload for CSV (developer tools, custom CSV import) — RN iOS shows "unsupported" | see §1.10 / §5.2 for optional native replacements |
| `__WORD7000_CONFIG__` runtime config injection | web build |
| `auth-native.html` bridge page itself (keep it deployed — native OAuth still redirects through it) | `public/` |
| Library scroll-position restore after returning from detail (web only; native navigation preserves scroll naturally) | |
| EAS OTA updates (`expo-updates`) | native-RN only, no Swift equivalent |

### 10.6 Misc behaviors worth matching

* Tabs keep their state while switching (each tab screen stays mounted); summary numbers on Home/Profile are recomputed when those tabs are focused.
* Library list resets scroll to top on tab change and when filters/sort change.
* The study tab and quiz tab both share the active bank; changing the bank from any tab affects all.
* `level` filters that do not exist in the new bank reset to `all`.
* Day rollover while the app is open: studiedToday resets, streak expires if needed, Home ring updates.
* Performance profile: `isLegacyIos` = iOS < 19 (i.e. 16–18): simpler push animation and fewer animated rows; `conserveResources` = Low Power Mode or Reduce Motion; `supportsLiquidGlass` = iOS ≥ 26 && !lowPower && !reduceTransparency.

---

## 11. Prioritized porting checklist

**M0 — Project skeleton (½ week)**
- [ ] Xcode project, bundle id `com.rio.word7000`, build number > 25, iPhone-only portrait, Sign in with Apple, URL scheme `word7000`, Info.plist camera/photos strings, `NSSupportsLiveActivities`, push entitlement, widget extension `com.rio.word7000.ExpoWidgetsTarget`, App Group `group.com.rio.word7000`.
- [ ] `.xcconfig` with `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY`; `supabase-swift` SPM package.
- [ ] Export `words.json` (+ precomputed pinyin) from `src/data/words.ts`; build-time validation (7000, unique).

**M1 — Core engine, pure Swift + tests (1 week)**
- [ ] Models `WordEntry`, `WordProgress`, `ProgressState`, `LearningAnalyticsState`, `CustomSetState` with lossless Codable and RN validators.
- [ ] Port `progress.ts` (SRS, daily/streak, filterWords/search, computeStats, buildStudyQueue, quiz session/options, merge), PRNG, `studySession.ts`, `learningAnalytics*.ts`, `chineseDisplay.ts`, `conversationPrompts.ts`, `customSets.ts`, `wordBanks.ts`, `scanParser.ts`.
- [ ] Port the vitest suites listed in §3/§5 to XCTest (progress, studySession, learningAnalytics, conversationPrompts, customSets, wordBanks, scanParser, filterPreferences, progressStorage, userMemorySync, streakReminder, nativeUpdatePolicy, oauthCallback, accountIdentity).

**M2 — Persistence + migration (½ week)**
- [ ] Key-value store with the same keys/JSON; debounced progress writer; flush on background.
- [ ] AsyncStorage importer (§6.2/6.4) with fixtures; session restore from `sb-*-auth-token`.

**M3 — Main UI (2 weeks)**
- [ ] Tab shell + headers, theme system (§9), haptics, motion profile.
- [ ] Home (ring, stats, dictionary sheet, action rows, mode toggle + overlay).
- [ ] Study (deck, swipe physics, reveal, grade buttons, undo, summary, filters).
- [ ] Quiz (setup, choice, speaking, results, missed practice).
- [ ] Library (header, search, chips, filter panel, virtualized list, fast scroll, word detail).
- [ ] Bank picker sheet; Profile; Settings; Stats (Swift Charts with scrubbing).
- [ ] Full string catalog (zh-Hant + en) keyed by studyMode, not device locale.

**M4 — Accounts & sync (1 week)**
- [ ] Bootstrap (session restore → anonymous sign-in), `activate()` merge, status messages.
- [ ] Google (link/sign-in via hosted bridge + ASWebAuthenticationSession), Apple (nonce, link via id_token, metadata), email.
- [ ] Sync queue with outbox + backoff, heartbeat, sign-out, account deletion, upgrade sheet + gating.

**M5 — Custom sets & scanning (1 week)**
- [ ] Set picker, My Sets list/detail, manual add, (optional) CSV import via file importer.
- [ ] Scan: PhotosPicker/camera, Vision recognizer (§5.4), review/edit, save to bank, saved state.

**M6 — Live Activity (½–1 week)**
- [ ] `LiveActivityAttributes` compatible with server payload; all presentations (§8.5).
- [ ] Local streak plan + clock timer; push-to-start token observation; `live_activity_devices` registration queue.
- [ ] End-to-end test with the production cron function (sandbox APNs for dev builds).

**M7 — Release (½ week)**
- [ ] Update-policy check + blocking overlay; bump `ios-update.json` `latestBuild`.
- [ ] Migration test matrix: guest-only, guest with unsynced outbox, permanent Google/Apple/email user, local-only (no Supabase), user mid-sign-in (pending upgrade present), scanned banks, developer preview vocabulary.
- [ ] Privacy manifest (UserDefaults/file timestamp reasons), App Store account-deletion compliance, TestFlight.

---

## 12. Open risks and questions

1. **Supabase credentials are not in the repo.** URL/publishable key live in EAS environment variables; confirm the project ref (`byyaepkhxexppjrdhcaw`) and fetch the key before M4. The derived session key `sb-<ref>-auth-token` depends on it.
2. **Guest identity continuity.** Guests' cloud data is keyed by an anonymous UUID whose only credential is the refresh token inside AsyncStorage. If the session import fails, the guest's cloud copy is orphaned (local data still migrates). Refresh tokens rotate — import before any RN code could run again, and never run both apps against the same token.
3. **Unsynced writes.** Outbox and pending-upgrade keys must be honored on first launch, otherwise the last few minutes of study before the update are lost.
4. **Live Activity compatibility.** The server targets `attributes-type: LiveActivityAttributes` and topic `com.rio.word7000.push-type.liveactivity`; the native extension must use that exact type name and ContentState shape, and existing push-to-start tokens change when the extension is rebuilt — re-registration happens automatically via the token stream. Pushes during the transition to devices still on RN builds keep working.
5. **Last-writer-wins cloud documents.** Whole-JSON upserts + read-only-at-activation means concurrent use on two devices (or RN web + native) can overwrite newer data until relaunch. Parity keeps this; consider pull-merge on foreground later.
6. **Sort stability.** JS `Array.sort` is stable; Swift's `sort` is not guaranteed stable. Every sort in §3–§5 needs an explicit index tiebreak, or study queues / search results will differ.
7. **String comparison semantics.** Several merges compare ISO strings/`YYYY-MM-DD` lexicographically and `Date.parse` values; replicate exactly (string compare, not `Date` compare, where the source does). `localeCompare(…, 'en', base)` vs Foundation comparisons can differ for punctuation in custom words.
8. **Pinyin parity.** `pinyin-pro` vs `CFStringTransform` differ on polyphonic characters; ship precomputed pinyin for built-in words.
9. **UTF-16 vs Swift Characters.** The PRNG hash and the 1024-character AsyncStorage inline threshold use UTF-16 code units; the scan parser iterates by Unicode code points (`for…of`); use `.utf16` / `.unicodeScalars` accordingly.
10. **Untranslated status messages.** Several account messages have no English mapping (listed in §1.12.6) and appear in Chinese in English UI; decide whether to fix (recommended) or keep for parity.
11. **Developer tools / CSV import on iOS** are effectively non-functional in RN; decide to implement (file importer/share sheet) or hide.
12. **Deployment target.** Push-to-start needs iOS 17.2; Liquid Glass styling needs iOS 26; the RN scanner pod declares iOS 15.1 and the RN app has explicit "legacy" iOS 16–18 paths. Pick a minimum (recommend iOS 17) and accept dropping older devices, or gate features.
13. **Build-number policy.** `ios-update.json` `minimumBuild` (23) forces older RN builds to update; once the native build ships, raising `minimumBuild` will push all RN users to TestFlight/App Store — coordinate with migration readiness.
14. **Account deletion for guests** is allowed (button enabled for any user id); App Review expects deletion for real accounts — fine, but make sure the guest path doesn't confuse users.
15. **Expo SDK mismatch note.** `AGENTS.md` refers to SDK 56 docs while the project is on SDK 57; irrelevant to Swift but relevant if anyone must still patch the RN app during the transition.
