import SwiftUI

/// Shared by menu actions and the existing window, including while it is closed.
@MainActor
final class SettingsPresentation: ObservableObject {
    @Published var helpExpanded = false

    func showHowToUse() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { helpExpanded = true }
    }
}

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var state: MenuBarState
    @ObservedObject var presentation = SettingsPresentation()
    let supported: Bool
    var requestAccessibility: () -> Void = {}

    @State private var advancedExpanded = false
    @State private var languageExpanded = false

    private var advancedExpansion: Binding<Bool> {
        // Send one final height to SettingsWindowController; it animates the
        // bottom edge without animating SwiftUI's intrinsic height in parallel.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return $advancedExpanded.transaction(transaction)
    }

    private var helpExpansion: Binding<Bool> {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return $presentation.helpExpanded.transaction(transaction)
    }

    private var languageExpansion: Binding<Bool> {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return $languageExpanded.transaction(transaction)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                LessBarMark().fill(.primary).frame(width: 30, height: 15)
                    .accessibilityHidden(true)
                Text(L10n.appName).font(.system(size: 20, weight: .semibold))
                Spacer()
            }
            .padding(.bottom, 24)

            generalSettings
                .padding(.bottom, 28)

            DisclosureGroup(isExpanded: advancedExpansion) {
                advancedSettings.padding(.top, 12)
            } label: {
                Text(L10n.advanced)
            }

            DisclosureGroup(isExpanded: languageExpansion) {
                Picker(L10n.language, selection: $preferences.language) {
                    Text(L10n.systemLanguage).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("한국어").tag(AppLanguage.korean)
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                .accessibilityLabel(L10n.language)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            } label: {
                Text(L10n.language)
            }
            .padding(.top, 14)

            DisclosureGroup(isExpanded: helpExpansion) {
                if presentation.helpExpanded {
                    UsageGuide(showChevron: preferences.showsChevron(accessibilityGranted: state.accessibilityGranted),
                        hover: state.accessibilityGranted && preferences.showOnHover,
                        click: state.accessibilityGranted && preferences.showOnClick)
                        .id(preferences.language)
                        .padding(.top, 12)
                }
            } label: {
                Text(L10n.howToUse)
            }
            .padding(.top, 14)

            if !state.accessibilityGranted {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.accessibilityNeeded).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.allowAccessibility, action: requestAccessibility)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
            }

            if !preferences.loginMessage.isEmpty {
                Text(preferences.loginMessage).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            }
            if !supported {
                Text(L10n.unsupported).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }
            if !state.feedback.isEmpty {
                Text(state.feedback).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }
            if !state.sharingFeedback.isEmpty {
                Text(state.sharingFeedback).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }
        }
        .disclosureGroupStyle(SettingsDisclosureStyle())
        .padding(20)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { preferences.refreshLoginStatus() }
        .onChange(of: preferences.showChevron) { shown in
            // Open only on the transition to hidden, so users can fold this
            // section again and it stays folded on a fresh settings session.
            if !shown { advancedExpansion.wrappedValue = true }
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            toggleRow(L10n.launchAtLogin, value: Binding(
                get: { preferences.launchAtLogin },
                set: { preferences.setLaunchAtLogin($0) }
            ))
            toggleRow(L10n.showChevron, value: $preferences.showChevron)
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            toggleRow(L10n.showOnHover, value: $preferences.showOnHover,
                isLocked: preferences.showOnHover && !preferences.canDisableHover,
                information: preferences.showOnHover && !preferences.canDisableHover ? L10n.revealRequired : nil)
                .help(L10n.showOnHoverDetail)
            toggleRow(L10n.showOnClick, value: $preferences.showOnClick,
                isLocked: preferences.showOnClick && !preferences.canDisableClick,
                information: preferences.showOnClick && !preferences.canDisableClick ? L10n.revealRequired : nil)
                .help(L10n.showOnClickDetail)
            toggleRow(L10n.autoRehide, value: $preferences.autoRehide,
                isLocked: preferences.requiresAutoRehide,
                information: preferences.requiresAutoRehide ? L10n.autoRehideRequired : nil)
                .help(L10n.autoRehideDetail)
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.timing).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                sliderRow(L10n.hoverDelay, value: $preferences.hoverDelay,
                          range: 0...2, step: 0.1, format: L10n.secondsFormat)
                    .disabled(!preferences.showOnHover)
                sliderRow(L10n.rehideDelay, value: $preferences.rehideDelay,
                          range: 0...10, step: 0.1, format: L10n.secondsFormat)
                    .disabled(!preferences.autoRehide)
            }
            .padding(.top, 4)
        }
    }

    private func toggleRow(_ title: String, value: Binding<Bool>, isLocked: Bool = false,
                           information: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if let information {
                SettingInformation(title: title, message: information)
            }
            Spacer()
            Toggle(title, isOn: value)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isLocked)
                .accessibilityLabel(title)
        }
        .frame(minHeight: 20)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, format: (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(format(value.wrappedValue)).font(.system(size: 11)).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(format(value.wrappedValue))
        }
        .padding(.leading, 4)
    }
}

/// One native button owns the entire header, including the arrow-label gap.
/// Keep content outside the button so sliders and radio buttons remain independent.
private struct SettingsDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .frame(width: 8)
                        .accessibilityHidden(true)
                    configuration.label
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? L10n.expanded : L10n.collapsed)
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

/// A focusable explanation remains available even when its switch is locked.
private struct SettingInformation: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(L10n.settingInformation(title))
        .help(message)
        .popover(isPresented: $isPresented) {
            Text(message).font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                .padding(14).frame(width: 260, alignment: .leading)
        }
    }
}

/// The same 256 × 128 geometry as Resources/Brand/lessbar-mark.svg.
private struct LessBarMark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / 256, rect.height / 128)
        let origin = CGPoint(x: rect.midX - 128 * scale, y: rect.midY - 64 * scale)
        var path = Path()
        path.addRoundedRect(in: CGRect(x: origin.x + 20 * scale, y: origin.y + 40 * scale,
            width: 144 * scale, height: 48 * scale), cornerSize: CGSize(width: 24 * scale, height: 24 * scale))
        path.addEllipse(in: CGRect(x: origin.x + 188 * scale, y: origin.y + 40 * scale,
            width: 48 * scale, height: 48 * scale))
        return path
    }
}
