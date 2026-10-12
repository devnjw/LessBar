import Foundation

/// Pure state machine for menu-bar reveal, temporary reveal, and rehide timing.
/// The coordinator supplies monotonic timestamps and translates actions to AppKit.
struct InteractionPolicy {
    struct Configuration {
        var showOnClick = true
        var showOnHover = true
        var hoverDelay: TimeInterval = 0.2
        var autoRehide = true
        var rehideStrategy: RehideStrategy = .afterExit
        var rehideDelay: TimeInterval = 3
        var showAllOnCommandDrag = true
        var enableAlwaysHidden = false
        var temporaryShowDelay: TimeInterval = 15
    }

    struct Input {
        var now: TimeInterval
        /// Display under the pointer, or nil when the pointer is outside all menu bars.
        var menuDisplayID: UInt32?
        /// Display whose empty menu-bar region contains the pointer, or nil otherwise.
        var emptyDisplayID: UInt32?
        var clickOnEmpty = false
        var requestRevealAll = false
        var mouseDown = false
        var command = false
        var menuOpen = false
        var dragInProgress = false
        var settingsPinned = false
    }

    enum Action: Equatable {
        case revealNormal
        case revealAll
        case beginEditing
        case endEditing(didDrag: Bool)
        case collapse
        case endTemporaryAll
    }

    private(set) var normalVisible = false
    private(set) var allVisible = false
    private(set) var editing = false

    private var lastEmptyDisplayID: UInt32?
    private var hoverDeadline: TimeInterval?
    private var rehideDeadline: TimeInterval?
    private var temporaryDeadline: TimeInterval?
    private var manualCollapseRequiresExit = false
    private var didDragDuringEditing = false
    private var previousRevealAllRequest = false
    private var previousShowOnHover: Bool?
    private var previousHoverDelay: TimeInterval?

    mutating func didReveal(now: TimeInterval, temporaryAll: Bool = false,
                            temporaryDelay: TimeInterval? = nil) {
        normalVisible = true
        allVisible = temporaryAll
        rehideDeadline = nil
        hoverDeadline = nil
        if temporaryAll {
            allVisible = true
            temporaryDeadline = now + max(0, temporaryDelay ?? currentConfiguration.temporaryShowDelay)
        } else {
            temporaryDeadline = nil
        }
    }

    mutating func didCollapse(pointerInMenuBar: Bool) {
        normalVisible = false
        allVisible = false
        rehideDeadline = nil
        temporaryDeadline = nil
        hoverDeadline = nil
        manualCollapseRequiresExit = pointerInMenuBar
    }

    private var currentConfiguration = Configuration()

    /// Apply one observation. Duplicate state transitions are suppressed.
    mutating func step(_ input: Input, configuration: Configuration) -> [Action] {
        currentConfiguration = configuration
        var actions: [Action] = []

        // A collapse while the pointer remains on a menu bar must not immediately reopen.
        if input.menuDisplayID == nil { manualCollapseRequiresExit = false }

        let enteredEmpty = input.emptyDisplayID != nil && input.emptyDisplayID != lastEmptyDisplayID
        let hoverSettingChanged = previousShowOnHover.map { $0 != configuration.showOnHover } ?? false
        let hoverDelayChanged = previousHoverDelay.map { $0 != configuration.hoverDelay } ?? false
        if !configuration.showOnHover {
            hoverDeadline = nil
        } else if input.emptyDisplayID != nil && !manualCollapseRequiresExit &&
                    ((hoverSettingChanged && configuration.showOnHover) || (hoverDelayChanged && hoverDeadline != nil)) {
            hoverDeadline = input.now + max(0, configuration.hoverDelay)
        } else if enteredEmpty {
            hoverDeadline = !manualCollapseRequiresExit
                ? input.now + max(0, configuration.hoverDelay) : nil
        } else if input.emptyDisplayID == nil {
            hoverDeadline = nil
        }
        previousShowOnHover = configuration.showOnHover
        previousHoverDelay = configuration.hoverDelay
        lastEmptyDisplayID = input.emptyDisplayID

        let allRequestEdge = input.requestRevealAll && !previousRevealAllRequest
        previousRevealAllRequest = input.requestRevealAll

        if allRequestEdge {
            if !allVisible { actions.append(.revealAll) }
            allVisible = true
            normalVisible = true
            temporaryDeadline = input.now + max(0, configuration.temporaryShowDelay)
            rehideDeadline = nil
        } else if input.clickOnEmpty, configuration.showOnClick, input.emptyDisplayID != nil,
                  !normalVisible {
            actions.append(.revealNormal)
            normalVisible = true
            rehideDeadline = nil
        }

        let hoverBlocked = input.mouseDown || input.command || input.menuOpen || input.settingsPinned
        if let deadline = hoverDeadline, input.now + 1e-9 >= deadline,
           input.emptyDisplayID != nil, !manualCollapseRequiresExit, !normalVisible,
           !hoverBlocked {
            actions.append(.revealNormal)
            normalVisible = true
            hoverDeadline = nil
            rehideDeadline = nil
        }

        let commandInMenu = input.command && input.menuDisplayID != nil

        if commandInMenu, configuration.showAllOnCommandDrag, !editing {
            editing = true
            didDragDuringEditing = false
            actions.append(.beginEditing)
        }
        if editing && input.dragInProgress { didDragDuringEditing = true }
        if !input.command && !input.mouseDown && editing {
            editing = false
            actions.append(.endEditing(didDrag: didDragDuringEditing))
            didDragDuringEditing = false
        }

        let blockers = input.mouseDown || input.command || input.dragInProgress || input.menuOpen || input.settingsPinned
        if configuration.autoRehide && normalVisible && !allVisible {
            switch configuration.rehideStrategy {
            case .afterExit:
                if input.menuDisplayID == nil {
                    // Start after an already-outside reveal, and restart after each exit.
                    if rehideDeadline == nil {
                        rehideDeadline = input.now + max(0, configuration.rehideDelay)
                    }
                } else {
                    // Returning to any display cancels the exit timer.
                    rehideDeadline = nil
                }
            case .timed:
                if rehideDeadline == nil {
                    rehideDeadline = input.now + max(0, configuration.rehideDelay)
                }
            }
        } else {
            rehideDeadline = nil
        }

        if !blockers, let deadline = rehideDeadline, input.now >= deadline, normalVisible {
            actions.append(.collapse)
            normalVisible = false
            allVisible = false
            rehideDeadline = nil
            manualCollapseRequiresExit = input.menuDisplayID != nil
            hoverDeadline = nil
        }

        if !blockers, let deadline = temporaryDeadline, input.now >= deadline, allVisible {
            actions.append(.endTemporaryAll)
            allVisible = false
            temporaryDeadline = nil
        }

        // Pointer movement between empty regions on different monitors starts a fresh dwell.
        return actions
    }
}
