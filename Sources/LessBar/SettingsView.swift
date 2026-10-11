import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var state: MenuBarState
    let supported: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                LessBarMark().fill(.primary)
                    .frame(width: 30, height: 15).accessibilityHidden(true)
                Text("LessBar").font(.system(size: 20, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.guideTitle)
                    .font(.system(size: 14, weight: .medium))

                MenuBarGuide(isCollapsed: state.isCollapsed)

                Text(L10n.dragInstruction)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: toggle) {
                    Label(state.isCollapsed ? L10n.showIcons : L10n.hideIcons,
                          systemImage: state.isCollapsed ? "chevron.left" : "chevron.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!supported)
                .accessibilityLabel(state.isCollapsed ? L10n.showIcons : L10n.hideIcons)
            }

            Divider()

            HStack {
                Text(L10n.launchAtLogin).font(.system(size: 13))
                Spacer()
                Toggle(L10n.launchAtLogin, isOn: Binding(
                    get: { preferences.launchAtLogin },
                    set: { preferences.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if !preferences.loginMessage.isEmpty {
                Text(preferences.loginMessage).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !supported {
                Text(L10n.unsupported)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24).frame(width: 360)
        .onAppear { preferences.refreshLoginStatus() }
    }
}

/// A noninteractive usage example; the actual control is the labeled button below.
private struct MenuBarGuide: View {
    let isCollapsed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                HStack(spacing: 15) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.secondary.opacity(0.6))
                            .frame(width: 13, height: 13)
                    }
                }
                .opacity(isCollapsed ? 0.12 : 1)
                .frame(maxWidth: .infinity)

                Image(systemName: isCollapsed ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32)

                HStack(spacing: 15) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100percent")
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
            }
            .frame(height: 44)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.06)))

            HStack(spacing: 0) {
                Text(L10n.hiddenIcons).frame(maxWidth: .infinity)
                Color.clear.frame(width: 32, height: 1)
                Text(L10n.visibleIcons).frame(maxWidth: .infinity)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isCollapsed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.guideAccessibility)
        .accessibilityValue(isCollapsed ? L10n.collapsed : L10n.expanded)
        .allowsHitTesting(false)
    }
}

/// The same 256 × 128 geometry as Resources/Brand/lessbar-mark.svg.
/// Vector drawing follows the system foreground color in light and dark mode.
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
