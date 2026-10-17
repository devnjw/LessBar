import SwiftUI

/// Time-sampled loops have no reset frame or accumulating animation tasks.
/// The resting interval on both sides of the seam has identical visual state.
enum UsageGuideAnimation {
    enum Method: CaseIterable { case hover, click, chevron }

    struct Frame: Equatable {
        var placement: Double = 0
        var hidden: Double = 0
        var editing = false
        var cursorX: Double = 240
        var cursorY: Double = 16
        var cursorOpacity: Double = 0
        var click: Double = 0
    }

    static let arrangementDuration = 11.2
    static let revealDuration = 7.2

    static func arrangement(at elapsed: Double) -> Frame {
        let t = phase(elapsed, duration: arrangementDuration)
        let placement = ease(t, 1.2, 2.7) - ease(t, 7.7, 9.2)
        // Move the headphones across the boundary, hide, expand, then drag back.
        let cursorX = 240 - 72 * placement
            + 72 * (ease(t, 3.2, 3.7) - ease(t, 6.6, 7.1))
        return Frame(
            placement: placement,
            hidden: ease(t, 4.1, 4.5) - ease(t, 5.5, 5.9),
            editing: (0.9..<3.0).contains(t) || (7.3..<9.6).contains(t),
            cursorX: cursorX,
            cursorY: 16 - 7 * sin(.pi * placement),
            cursorOpacity: ease(t, 0.4, 0.8) - ease(t, 9.8, 10.2),
            click: pulse(t, at: 4.0) + pulse(t, at: 5.4)
        )
    }

    static func reveal(at elapsed: Double, method: Method) -> Frame {
        let t = phase(elapsed, duration: revealDuration)
        let chevron = method == .chevron
        let departure = ease(t, chevron ? 4.6 : 3.6, chevron ? 5.2 : 4.2)
        let arrival = ease(t, 0.4, 1.0)
        return Frame(
            hidden: 1 - ease(t, 1.4, 1.8) + ease(t, chevron ? 3.9 : 5.0, chevron ? 4.3 : 5.4),
            cursorX: chevron ? 240 : 140,
            cursorY: 42 - 26 * arrival + 26 * departure,
            cursorOpacity: arrival - departure,
            click: method == .hover ? 0 : pulse(t, at: 1.3) + (chevron ? pulse(t, at: 3.8) : 0)
        )
    }

    private static func phase(_ elapsed: Double, duration: Double) -> Double {
        max(0, elapsed).truncatingRemainder(dividingBy: duration)
    }

    private static func ease(_ time: Double, _ start: Double, _ end: Double) -> Double {
        let progress = min(1, max(0, (time - start) / (end - start)))
        return progress * progress * (3 - 2 * progress)
    }

    private static func pulse(_ time: Double, at start: Double) -> Double {
        ease(time, start, start + 0.08) - ease(time, start + 0.08, start + 0.32)
    }
}

/// Illustrations never interact with the user's real menu bar.
struct UsageGuide: View {
    let showChevron: Bool
    let hover: Bool
    let click: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var windowOpen = true

    private var methods: [UsageGuideAnimation.Method] {
        let enabled: [UsageGuideAnimation.Method] = (hover ? [.hover] : []) + (click ? [.click] : [])
        return enabled.isEmpty ? [.chevron] : enabled
    }
    private var instruction: String {
        if hover && click { return L10n.guideHoverAndClick }
        if hover { return L10n.guideHover }
        if click { return L10n.guideClick }
        return L10n.guideChevron
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !windowOpen)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let method = methods[Int(elapsed / UsageGuideAnimation.revealDuration) % methods.count]
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.arrangeIcons).font(.system(size: 12, weight: .medium))
                    description(L10n.dragInstruction)
                    arrangement(UsageGuideAnimation.arrangement(at: reduceMotion ? 2.8 : elapsed))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.revealIcons).font(.system(size: 12, weight: .medium))
                    description(instruction)
                    reveal(UsageGuideAnimation.reveal(at: reduceMotion ? 2.4 : elapsed,
                        method: reduceMotion ? methods[0] : method))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if isSettings(note) { windowOpen = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { note in
            if isSettings(note) { windowOpen = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if isSettings(note), !windowOpen { startedAt = Date(); windowOpen = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { note in
            if isSettings(note), !windowOpen { startedAt = Date(); windowOpen = true }
        }
    }

    private func isSettings(_ note: Notification) -> Bool {
        (note.object as? NSWindow)?.title == L10n.settingsTitle
    }

    private func description(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func arrangement(_ frame: UsageGuideAnimation.Frame) -> some View {
        illustration {
            let shift = 24 * frame.placement
            icon("bubble.left.and.bubble.right.fill", x: 168 + shift, hidden: frame.hidden)
            icon("cloud.fill", x: 192 + shift, hidden: frame.hidden)
            icon("headphones", x: 240 - 72 * frame.placement,
                y: 16 - 7 * sin(.pi * frame.placement), hidden: frame.hidden)
            boundary(x: 216 + shift, hidden: frame.hidden, editing: frame.editing)
            permanentIcons
            pointer(frame)
        }
    }

    private func reveal(_ frame: UsageGuideAnimation.Frame) -> some View {
        illustration {
            // Removing the arrow also removes its slot, just like the native item.
            let shift: Double = showChevron ? 0 : 24
            icon("bubble.left.and.bubble.right.fill", x: 168 + shift, hidden: frame.hidden)
            icon("cloud.fill", x: 192 + shift, hidden: frame.hidden)
            icon("headphones", x: 216 + shift, hidden: frame.hidden)
            if showChevron { boundary(x: 240, hidden: frame.hidden) }
            permanentIcons
            pointer(frame)
        }
    }

    private var permanentIcons: some View {
        Group {
            icon("wifi", x: 264)
            icon("speaker.wave.2.fill", x: 288)
            icon("battery.100percent", x: 312)
        }.foregroundStyle(.primary.opacity(0.8))
    }

    private func icon(_ name: String, x: Double, y: Double = 16, hidden: Double = 0) -> some View {
        Image(systemName: name)
            .opacity(1 - hidden)
            .position(x: x - 150 * hidden, y: y)
    }

    private func boundary(x: Double, hidden: Double, editing: Bool = false) -> some View {
        Group {
            if editing {
                Rectangle().frame(width: 1, height: 16)
            } else {
                Image(systemName: hidden > 0.5 ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13))
            }
        }.foregroundStyle(.primary.opacity(0.8)).position(x: x, y: 16)
    }

    private func pointer(_ frame: UsageGuideAnimation.Frame) -> some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(frame.click * 0.8), lineWidth: 1.5)
                .frame(width: 21, height: 21).position(x: frame.cursorX, y: frame.cursorY)
            Image(systemName: "cursorarrow").font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary).shadow(color: .black.opacity(0.25), radius: 1)
                .position(x: frame.cursorX + 5, y: frame.cursorY + 7)
                .opacity(frame.cursorOpacity)
        }
    }

    private func illustration<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack { content() }
            .font(.system(size: 13)).foregroundStyle(.secondary)
            .frame(width: 340, height: 36)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            .clipped()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
