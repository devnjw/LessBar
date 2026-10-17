import AppKit

/// A retained native boundary can be invisible without losing its saved position.
@MainActor
private final class StatusBoundary {
    let item: NSStatusItem
    private var paddingConstraint: NSLayoutConstraint?

    init(item: NSStatusItem) { self.item = item }

    func set(collapsed: Bool, visible: Bool) {
        if paddingConstraint == nil, let content = item.button?.window?.contentView {
            paddingConstraint = content.constraintsAffectingLayout(for: .horizontal).first {
                ($0.firstItem as AnyObject?) === content && $0.firstAttribute == .width &&
                $0.secondAttribute == .width && $0.relation == .equal && $0.constant > 0
            }
        }
        paddingConstraint?.isActive = collapsed || visible
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 1440
        item.length = collapsed ? max(500, min(widest * 2, 10_000)) : (visible ? LayoutSafety.controlWidth : 0)
        if !collapsed && !visible, let window = item.button?.window {
            window.setContentSize(NSSize(width: 1, height: window.frame.height))
        }
        item.button?.cell?.isEnabled = !collapsed
    }
}

@MainActor
final class LengthMenuBarEngine {
    private let normal: StatusBoundary
    private var alwaysHidden: StatusBoundary?
    private var showDividers = false
    private var editing = false
    private var mirrorPadding: [Int: NSLayoutConstraint] = [:]
    private var mirrorIsSecondary: [Int: Bool] = [:]
    private(set) var isCollapsed = false
    private(set) var alwaysCollapsed = false
    let isSupported: Bool
    var isAllExpanded: Bool { !isCollapsed && !alwaysCollapsed }
    var normalItem: NSStatusItem { normal.item }
    var secondaryItem: NSStatusItem? { alwaysHidden?.item }

    var anchors: [DisplayAnchor] {
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let items = NSApp.windows.filter { $0.level.rawValue == statusLevel }.map(StatusItemGeometry.capture)
        return MenuBarGeometry.recoveryAnchors(items: items, screens: NSScreen.screens.map {
            (MenuBarGeometry.displayID($0), $0.frame, $0.auxiliaryTopRightArea)
        })
    }

    var canCollapse: Bool {
        normal.item.isVisible && Set(anchors.map(\.displayID)) == Set(NSScreen.screens.map(MenuBarGeometry.displayID))
    }

    init(toggle: NSStatusItem, osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
        normal = StatusBoundary(item: toggle)
        isSupported = (13..<27).contains(osMajorVersion)
    }

    func configure(showDividers: Bool, alwaysHiddenEnabled: Bool, editing: Bool) {
        self.showDividers = showDividers
        self.editing = editing
        if alwaysHiddenEnabled, alwaysHidden == nil {
            let item = NSStatusBar.system.statusItem(withLength: LayoutSafety.controlWidth)
            item.autosaveName = "LessBar.AlwaysHidden"
            item.isVisible = true
            alwaysHidden = StatusBoundary(item: item)
            alwaysCollapsed = false
        } else if !alwaysHiddenEnabled, let boundary = alwaysHidden {
            let key = "NSStatusItem Preferred Position LessBar.AlwaysHidden"
            let position = UserDefaults.standard.object(forKey: key)
            NSStatusBar.system.removeStatusItem(boundary.item)
            if let position { UserDefaults.standard.set(position, forKey: key) }
            alwaysHidden = nil
            alwaysCollapsed = false
        }
        refreshLayout()
    }

    @discardableResult
    func setCollapsed(_ collapsed: Bool) -> Bool {
        if collapsed && !isCollapsed && (!isSupported || !canCollapse) { return false }
        isCollapsed = collapsed && isSupported
        if collapsed { alwaysCollapsed = alwaysHidden != nil }
        refreshLayout()
        return true
    }

    func reveal(all: Bool) {
        isCollapsed = false
        alwaysCollapsed = isSupported && alwaysHidden != nil && !all
        refreshLayout()
    }

    func hideAlwaysHidden() {
        alwaysCollapsed = isSupported && alwaysHidden != nil
        refreshLayout()
    }

    func refreshLayout() {
        // Update the left boundary before the right boundary to avoid momentarily
        // exposing the always-hidden group during ordinary reveal.
        alwaysHidden?.set(collapsed: alwaysCollapsed, visible: showDividers || editing)
        normal.set(collapsed: isCollapsed, visible: showDividers || editing)
        synchronizeMirrorSpacing()
    }

    func synchronizeMirrorSpacing() {
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let windows = NSApp.windows.filter { $0.level.rawValue == statusLevel }
        // Drop stale constraints and section assignments after AppKit discards
        // a mirror during a display/Space change.
        let liveIDs = Set(windows.map(\.windowNumber))
        mirrorPadding = mirrorPadding.filter { liveIDs.contains($0.key) }
        mirrorIsSecondary = mirrorIsSecondary.filter { liveIDs.contains($0.key) }
        if let primary = normal.item.button?.window { mirrorIsSecondary[primary.windowNumber] = false }
        if let secondary = alwaysHidden?.item.button?.window { mirrorIsSecondary[secondary.windowNumber] = true }
        if alwaysHidden == nil {
            windows.forEach { mirrorIsSecondary[$0.windowNumber] = false }
        } else if !isCollapsed && !alwaysCollapsed {
            for screen in NSScreen.screens {
                let matching = windows.filter {
                    $0.frame.maxX > screen.frame.minX && $0.frame.maxX <= screen.frame.maxX &&
                    abs($0.frame.maxY - screen.frame.maxY) < 4
                }.sorted { $0.frame.maxX < $1.frame.maxX }
                if matching.count == 2 {
                    if mirrorIsSecondary[matching[0].windowNumber] == nil { mirrorIsSecondary[matching[0].windowNumber] = true }
                    if mirrorIsSecondary[matching[1].windowNumber] == nil { mirrorIsSecondary[matching[1].windowNumber] = false }
                }
            }
        }
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 1440
        let collapsedLength = max(500, min(widest * 2, 10_000))
        for window in windows {
            guard let content = window.contentView else { continue }
            if mirrorPadding[window.windowNumber] == nil {
                mirrorPadding[window.windowNumber] = content.constraintsAffectingLayout(for: .horizontal).first {
                    ($0.firstItem as AnyObject?) === content && $0.firstAttribute == .width &&
                    $0.secondAttribute == .width && $0.relation == .equal && $0.constant > 0
                }
            }
            let secondary = mirrorIsSecondary[window.windowNumber] ?? false
            let collapsed = secondary ? alwaysCollapsed : isCollapsed
            let visible = collapsed || showDividers || editing
            mirrorPadding[window.windowNumber]?.isActive = visible
            let length: CGFloat = collapsed ? collapsedLength : ((showDividers || editing) ? LayoutSafety.controlWidth : 0)
            // AppKit updates only the active display's content-width constraint on
            // macOS 26. Apply the same length to each retained native mirror.
            for view in content.subviews {
                for constraint in view.constraints where constraint.firstAttribute == .width &&
                    constraint.secondItem == nil && constraint.relation == .equal && constraint.priority.rawValue >= 700 {
                    if abs(constraint.constant - length) > 0.01 { constraint.constant = length }
                }
            }
            let padding = visible ? (mirrorPadding[window.windowNumber]?.constant ?? 16) : 0
            let target = max(1, length + padding)
            if abs(window.frame.width - target) > 0.01 {
                window.setContentSize(NSSize(width: target, height: window.frame.height))
            }
        }
    }

    func validateBoundaryOrder() -> Bool {
        guard alwaysHidden != nil, !isCollapsed, !alwaysCollapsed else { return true }
        let windows = NSApp.windows.filter { $0.level.rawValue == Int(CGWindowLevelForKey(.statusWindow)) }
        for screen in NSScreen.screens {
            let matching = windows.filter {
                $0.frame.maxX > screen.frame.minX && $0.frame.maxX <= screen.frame.maxX &&
                abs($0.frame.maxY - screen.frame.maxY) < 4
            }
            guard let normalWindow = matching.first(where: { mirrorIsSecondary[$0.windowNumber] == false }),
                  let hiddenWindow = matching.first(where: { mirrorIsSecondary[$0.windowNumber] == true }),
                  hiddenWindow.frame.maxX <= normalWindow.frame.minX + 2 else { return false }
        }
        return true
    }

    func stop() {
        reveal(all: true)
        if let alwaysHidden { NSStatusBar.system.removeStatusItem(alwaysHidden.item) }
        alwaysHidden = nil
        mirrorPadding.removeAll()
        mirrorIsSecondary.removeAll()
    }
}
