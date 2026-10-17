import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var state: MenuBarState
    let supported: Bool
    var requestAccessibility: () -> Void = {}

    @State private var timingExpanded = false

    private var timingExpansion: Binding<Bool> {
        // Send one final height to SettingsWindowController; it animates the
        // bottom edge without animating SwiftUI's intrinsic height in parallel.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return $timingExpanded.transaction(transaction)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                LessBarMark().fill(.primary).frame(width: 30, height: 15)
                    .accessibilityHidden(true)
                Text("LessBar").font(.system(size: 20, weight: .semibold))
                Spacer()
            }
            .padding(.bottom, 15)

            VStack(alignment: .leading, spacing: 10) {
                MenuBarGuide(isCollapsed: state.isCollapsed,
                    showsChevron: !preferences.showOnHover || !state.accessibilityGranted)
                Text(L10n.dragInstruction)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 20)

            generalSettings

            Divider().padding(.vertical, 14)
            DisclosureGroup(isExpanded: timingExpansion) {
                VStack(spacing: 14) {
                    sliderRow(L10n.hoverDelay, value: $preferences.hoverDelay,
                              range: 0...2, step: 0.1, format: L10n.secondsFormat)
                        .disabled(!preferences.showOnHover)
                    sliderRow(L10n.rehideDelay, value: $preferences.rehideDelay,
                              range: 0...10, step: 0.1, format: L10n.secondsFormat)
                        .disabled(!preferences.autoRehide)
                }
                .padding(.top, 10)
            } label: {
                Text(L10n.timing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { timingExpansion.wrappedValue.toggle() }
            }

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
        .padding(20)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { preferences.refreshLoginStatus() }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            toggleRow(L10n.launchAtLogin, value: Binding(
                get: { preferences.launchAtLogin },
                set: { preferences.setLaunchAtLogin($0) }
            ))
            toggleRow(L10n.showOnHover, value: $preferences.showOnHover)
                .help(L10n.showOnHoverDetail)
            VStack(alignment: .leading, spacing: 4) {
                toggleRow(L10n.autoRehide, value: $preferences.autoRehide)
                    .disabled(preferences.showOnHover)
                    .help(preferences.showOnHover ? L10n.autoRehideRequiredForHover : L10n.autoRehideDetail)
                if preferences.showOnHover {
                    Text(L10n.autoRehideRequiredForHover)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func toggleRow(_ title: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: value)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
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
    let showsChevron: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Image(systemName: "cloud.fill")
                    Image(systemName: "headphones")
                }
                .font(.system(size: 14, weight: .medium))
                .opacity(isCollapsed ? 0.25 : 0.45)
                .frame(width: 88, alignment: .trailing)

                Image(systemName: isCollapsed ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    // Center the visible glyph, including its directional side bearing.
                    .offset(x: isCollapsed ? 1 : -1)
                    .frame(width: 18)
                    .opacity(showsChevron ? 1 : 0)

                HStack(spacing: 12) {
                    Image(systemName: "wifi")
                    Image(systemName: "speaker.wave.2.fill")
                    Image(systemName: "battery.100percent")
                }
                .font(.system(size: 14)).frame(width: 88, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.06)))

            HStack(spacing: 10) {
                Text(L10n.hiddenIcons).frame(width: 88)
                Color.clear.frame(width: 18, height: 1)
                Text(L10n.visibleIcons).frame(width: 88)
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
