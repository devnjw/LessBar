import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var state: MenuBarState
    let supported: Bool
    let toggle: () -> Void
    var temporaryShow: () -> Void = {}
    var requestAccessibility: () -> Void = {}

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                LessBarMark().fill(.primary).frame(width: 30, height: 15)
                    .accessibilityHidden(true)
                Text("LessBar").font(.system(size: 20, weight: .semibold))
                Spacer()
                Button(action: toggle) {
                    Label(state.isCollapsed ? L10n.showIcons : L10n.hideIcons,
                          systemImage: state.isCollapsed ? "chevron.left" : "chevron.right")
                }
                .buttonStyle(.bordered)
                .disabled(!supported)
                .accessibilityLabel(state.isCollapsed ? L10n.showIcons : L10n.hideIcons)
            }
            .padding(.bottom, 15)

            Picker(L10n.settingsTabs, selection: $selectedTab) {
                Text(L10n.generalTab).tag(0)
                Text(L10n.advancedTab).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 14)

            ScrollView {
                if selectedTab == 0 {
                    generalSettings
                } else {
                    advancedSettings
                }
                Spacer(minLength: 1)
            }
            .frame(maxHeight: 460)

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
        .padding(20)
        .frame(width: 440)
        .frame(minHeight: 350)
        .onAppear { preferences.refreshLoginStatus() }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingRow(L10n.showOnClick, detail: L10n.showOnClickDetail,
                       value: $preferences.showOnClick)
            settingRow(L10n.showOnHover, detail: L10n.showOnHoverDetail,
                       value: $preferences.showOnHover)
            if preferences.showOnHover {
                sliderRow(L10n.hoverDelay, value: $preferences.hoverDelay,
                          range: 0...2, step: 0.1, format: L10n.secondsFormat)
            }
            if !state.accessibilityGranted {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.accessibilityNeeded).font(.system(size: 11)).foregroundStyle(.secondary)
                    Button(action: requestAccessibility) {
                        Label(L10n.allowAccessibility, systemImage: "lock.open")
                    }
                    .buttonStyle(.bordered)
                }
            }
            Divider()
            settingRow(L10n.autoRehide, detail: L10n.autoRehideDetail,
                       value: $preferences.autoRehide)
            if preferences.autoRehide {
                Picker(L10n.rehideStrategy, selection: $preferences.rehideStrategy) {
                    Text(L10n.afterExitStrategy).tag(RehideStrategy.afterExit)
                    Text(L10n.timedStrategy).tag(RehideStrategy.timed)
                }
                .pickerStyle(.menu)
                sliderRow(L10n.rehideDelay, value: $preferences.rehideDelay,
                          range: 0...10, step: 0.1, format: L10n.secondsFormat)
            }
            Toggle(L10n.launchAtLogin, isOn: Binding(
                get: { preferences.launchAtLogin },
                set: { preferences.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingRow(L10n.showSectionDividers, detail: L10n.showSectionDividersDetail,
                       value: $preferences.showSectionDividers)
            settingRow(L10n.showAllOnCommandDrag, detail: L10n.showAllOnCommandDragDetail,
                       value: $preferences.showAllOnCommandDrag)
            settingRow(L10n.enableAlwaysHidden, detail: L10n.enableAlwaysHiddenDetail,
                       value: $preferences.enableAlwaysHidden)
            if preferences.enableAlwaysHidden {
                sliderRow(L10n.temporaryShowDelay, value: $preferences.temporaryShowDelay,
                          range: 1...60, step: 1, format: L10n.secondsFormat)
                Button(action: temporaryShow) {
                    Label(L10n.temporaryShowAll, systemImage: "eye")
                }
                .buttonStyle(.bordered)
            }
            settingRow(L10n.hideApplicationMenus, detail: L10n.hideApplicationMenusDetail,
                       value: $preferences.hideApplicationMenus)
            Divider()
            Text(L10n.guideTitle).font(.system(size: 13, weight: .medium))
            MenuBarGuide(isCollapsed: state.isCollapsed,
                         showDivider: preferences.showSectionDividers)
            Text(L10n.dragInstruction)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingRow(_ title: String, detail: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
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

/// A noninteractive usage example; real actions are provided by labeled controls.
private struct MenuBarGuide: View {
    let isCollapsed: Bool
    let showDivider: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                HStack(spacing: 15) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 3).fill(.secondary.opacity(0.6))
                            .frame(width: 13, height: 13)
                    }
                }
                .opacity(isCollapsed ? 0.12 : 1)
                .frame(maxWidth: .infinity)

                if showDivider {
                    Image(systemName: isCollapsed ? "chevron.left" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold)).frame(width: 32)
                } else {
                    Spacer().frame(width: 1)
                }

                HStack(spacing: 15) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100percent")
                }
                .font(.system(size: 14)).frame(maxWidth: .infinity)
            }
            .frame(height: 44)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.06)))

            HStack(spacing: 0) {
                Text(L10n.hiddenIcons).frame(maxWidth: .infinity)
                Color.clear.frame(width: showDivider ? 32 : 1, height: 1)
                Text(L10n.visibleIcons).frame(maxWidth: .infinity)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isCollapsed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.guideAccessibility)
        .accessibilityValue(isCollapsed ? L10n.collapsed : L10n.expanded)
        .allowsHitTesting(false)
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
