import SwiftUI

// WordCat Next: the settings pages' own controls, so the switches, choices
// and times look like the rest of WordCat rather than the iPhone's Settings
// app: clay and paper, a paw on the switch, choices laid out in the row
// instead of a menu popping up over the page.

/// The knob's cream: white by day, warm ivory at night.
private let knobCream = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.93, green: 0.9, blue: 0.85, alpha: 1)
        : .white
})

/// A switch drawn in clay and paper, a paw print on its knob.
struct WarmSwitch: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isOn: Bool
    var tint: Color = Palette.accent

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Palette.fill))
                .overlay { Capsule().strokeBorder(isOn ? Color.clear : Palette.khaki, lineWidth: 1) }
                // A little depth, as if pressed into the paper.
                .overlay {
                    Capsule().strokeBorder(.black.opacity(0.08), lineWidth: 1).blur(radius: 1).offset(y: 1)
                        .clipShape(Capsule())
                }
            Circle()
                .fill(knobCream)
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1.5)
                .overlay {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isOn ? tint : Palette.tertiaryLabel)
                        .rotationEffect(.degrees(isOn ? 0 : -18))
                }
                .padding(3)
        }
        .frame(width: 51, height: 31)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.68), value: isOn)
        .accessibilityHidden(true)
    }
}

/// Every switch in a WordCat list: the row's label, then a WarmSwitch; a
/// tap anywhere on the row flips it. VoiceOver and the UI tests meet the
/// iPhone's own switch, with the same label and value.
struct WarmToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                WarmSwitch(isOn: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
        }
    }
}

/// One choice of a ChoiceChips row.
struct ChoiceOption<Value: Hashable> {
    let value: Value
    let title: String
    var detail: String? = nil
    var icon: String? = nil
}

/// A few choices laid out in the row, the chosen one filled in clay with a
/// check: what a menu or a segmented control was. `identifier` names the
/// chips "identifier-0", "identifier-1", ….
struct ChoiceChips<Value: Hashable>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let options: [ChoiceOption<Value>]
    let selection: Value
    var tint: Color = Palette.accent
    /// Equal widths across one row; otherwise the chips wrap.
    var equalWidths = true
    var identifier: String
    let onPick: (Value) -> Void

    var body: some View {
        Group {
            if equalWidths {
                HStack(spacing: 8) { chips }
            } else {
                FlowLayout(spacing: 8, lineSpacing: 8) { chips }
            }
        }
        .animation(reduceMotion ? nil : Motion.pop, value: selection)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in model.settings.hapticsEnabled ?? true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var chips: some View {
        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
            let chosen = option.value == selection
            Button { if !chosen { onPick(option.value) } } label: {
                chip(option, chosen: chosen)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel([option.title, option.detail].compactMap { $0 }.joined(separator: "，"))
            .accessibilityAddTraits(chosen ? .isSelected : [])
            .accessibilityIdentifier("\(identifier)-\(index)")
        }
    }

    private func chip(_ option: ChoiceOption<Value>, chosen: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                if chosen {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .transition(.scale.combined(with: .opacity))
                } else if let icon = option.icon {
                    Image(systemName: icon).font(.caption.weight(.bold))
                }
                Text(option.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.subheadline.weight(.bold))
            if let detail = option.detail {
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .foregroundStyle(chosen ? Palette.surface : Palette.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, option.detail == nil ? 9 : 7)
        .frame(maxWidth: equalWidths ? .infinity : nil, minHeight: 38)
        .background {
            Capsule().fill(chosen ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Palette.fill))
        }
        .overlay {
            Capsule().strokeBorder(chosen ? Color.clear : Palette.khaki.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: chosen ? tint.opacity(0.3) : .clear, radius: 4, y: 2)
        .scaleEffect(chosen && !reduceMotion ? 1.02 : 1)
        .contentShape(Capsule())
    }
}

/// A settings row whose choices sit under its title.
struct ChoiceRow<Value: Hashable>: View {
    let title: String
    let icon: String
    let tint: Color
    let options: [ChoiceOption<Value>]
    let selection: Value
    var equalWidths = true
    var identifier: String
    let onPick: (Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsLabel(title, icon: icon, tint: tint, trigger: AnyHashable(selection))
            ChoiceChips(options: options, selection: selection, equalWidths: equalWidths,
                        identifier: identifier, onPick: onPick)
        }
        .padding(.vertical, 4)
    }
}

/// The value at the end of a settings row as a clay chip, e.g. the time of
/// the reminder, opening its own sheet when tapped.
struct ValueChip: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption.weight(.bold)) }
            Text(text).monospacedDigit().contentTransition(.numericText())
            Image(systemName: "chevron.down").font(.caption2.weight(.heavy)).opacity(0.6)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Palette.accent.opacity(0.13), in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.accent.opacity(0.35), lineWidth: 1) }
    }
}

/// "+" and "−" in clay circles, the number between: what a Stepper was.
struct WarmStepper: View {
    @Environment(AppModel.self) private var model
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            key("minus", enabled: value > range.lowerBound) { onChange(value - 1) }
            Text("\(value)")
                .font(.display(.headline, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .frame(minWidth: 26)
            key("plus", enabled: value < range.upperBound) { onChange(value + 1) }
        }
        .animation(Motion.pop, value: value)
        .sensoryFeedback(.selection, trigger: value) { _, _ in model.settings.hapticsEnabled ?? true }
    }

    private func key(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(enabled ? Palette.surface : Palette.tertiaryLabel)
                .frame(width: 32, height: 32)
                .background(Circle().fill(enabled ? AnyShapeStyle(Palette.accent.gradient) : AnyShapeStyle(Palette.fill)))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
    }
}

/// When the reminder comes: a few usual times to tap, or any other on the wheel.
struct ReminderTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @Binding var minute: Int

    private static let presets: [(minute: Int, zh: String, en: String, icon: String)] = [
        (7 * 60 + 30, "早上", "Morning", "sunrise.fill"),
        (12 * 60 + 30, "午休", "Lunch", "fork.knife"),
        (17 * 60 + 30, "放學後", "After school", "figure.walk"),
        (20 * 60, "晚上", "Evening", "moon.fill"),
        (21 * 60 + 30, "睡前", "Bedtime", "bed.double.fill"),
    ]

    static func label(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Mascot(mood: .happy, size: 54).accessibilityHidden(true)
                        Text(L.t("你通常什麼時候有空？我那時候來叫你。", "When are you usually free? I'll come and get you then."))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ChoiceChips(
                        options: Self.presets.map {
                            ChoiceOption(value: $0.minute, title: Self.label($0.minute), detail: L.t($0.zh, $0.en), icon: $0.icon)
                        },
                        selection: minute, equalWidths: false, identifier: "reminder-preset"
                    ) { minute = $0 }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("其他時間", "Another time"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryLabel)
                        DatePicker("", selection: Binding(
                            get: { Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date() },
                            set: { date in
                                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                                minute = (parts.hour ?? 12) * 60 + (parts.minute ?? 0)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .background(Palette.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background { AmbientBackground(tint: Palette.miss) }
            .navigationTitle(L.t("提醒時間", "Reminder time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }.accessibilityIdentifier("reminder-time-done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

/// A day on a calendar in WordCat's colours, e.g. the exam's.
struct WarmDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var date: Date
    var from: Date = Date()

    var body: some View {
        NavigationStack {
            DatePicker("", selection: $date, in: from..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Palette.accent)
                .padding(12)
                .background { PremiumSurface(radius: 22) }
                .padding(.horizontal, Metrics.gutter)
                .frame(maxHeight: .infinity, alignment: .top)
                .background { AmbientBackground(tint: Palette.review) }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.done) { dismiss() }.accessibilityIdentifier("date-sheet-done")
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}
