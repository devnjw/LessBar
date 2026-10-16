# Architecture

LessBar uses Swift, AppKit and SwiftUI with no third-party dependencies.

| Component | Responsibility |
| --- | --- |
| `AppDelegate` | App lifecycle, prototype preference migration and settings window |
| `MenuBarController` | Native status item/menu, hide/show coordination, published UI state |
| `MenuBarEngine` | OS-dependent status-item width strategy and support gate |
| `RecoveryController` | Independent reveal button, placement, timer ownership and teardown |
| `LayoutRecovery` | Testable bounded retry policy for asynchronous menu layout |
| `LayoutSafety` | Pure geometry: coordinate conversion and collision-free positioning |
| `MenuBarOccupancy` | Public Window Server geometry query; no titles or screenshots |
| `SharingIndicator` | Exact system-control identification, safe placement and bounded automatic reordering |
| `MenuBarVisibility` | Per-display system menu bar visibility from public Window Server geometry |
| `Preferences` | ServiceManagement login registration and narrow preference migration |
| `SettingsView` / `L10n` | Minimal settings UI and English/Korean resources |

## Collapse lifecycle

Capture the user's boundary before changing the native status-item width. Prepare independent nonactivating panels and validate placement on every display before collapsing. Show the panels without animation in the native chevron's current direction, collapse the native item, then flip the replacement chevrons immediately. This keeps a control visible across the transition without waiting for the first retry timer. Unknown or unsafe placement leaves the native item expanded. Never show a panel over an occupied system item.

During initial settling or an unsafe snapshot, check every 75 ms. A continuous unsafe interval of 750 ms triggers expansion. Once settled, check every 500 ms. A fresh safe sample clears the failure deadline. A display change reveals immediately.

Recovery panels follow each display's actual system menu bar. A 100 ms visibility poll and Space-change refresh hide panels when the full-width system menu bar is absent, transparent or sliding offscreen, including full-screen video and desktop auto-hide. Hidden menu bars keep the shared collapsed state without triggering recovery failure. When a menu bar returns, collision checks run before restoring its panel; other displays remain independent. Unknown visibility hides panels until a known visible menu bar returns. Queries inspect only window layers, bounds and alpha, requiring neither screen capture nor window titles.

The recovery controller owns its safety, retry and visibility timers. Revealing invalidates them, clears the session and removes the panel. Delayed clicks are checked against panel identity; cancelled retry callbacks are checked against timer identity. Recovery always reveals rather than toggles, preventing stale callbacks from collapsing a new session.

The engine is the source of truth for the published state. Both native and settings controls use the same transition path. The recovery timers only run while collapsed. The input coordinator samples pointer/modifier state every 50 ms and refreshes geometry every 200 ms; it never observes typed key content.

## Shared multi-display interaction

`InteractionPolicy` is a pure monotonic-time state machine. Preferences and visibility are shared by all displays; hover dwell resets when changing display. `MenuBarGeometry` excludes application-menu rectangles, status items and the notch. Accessibility is used only to read menu geometry; unknown geometry cannot trigger reveal.

`LengthMenuBarEngine` retains native boundaries and preserves their autosaved positions. Native content-width constraints and padding are synchronized for every retained mirrored window; setting NSStatusItem.length alone changes only the active display on the tested macOS 26 build. Invisible expanded boundaries use a one-point window. Native status windows are tracked through AppKit rather than owner PID, because Window Server reports them under Control Center. External collision checks exclude native window IDs or an exact matching frame.

`RecoveryController` creates one collision-checked panel per display and refuses partial display coverage. With dividers off, these panels stay ordered out. Display changes cancel stale work, reveal while layout settles, then restore the shared collapsed state. Closing and reopening settings remains the recovery route with invisible controls.

Application-menu hiding temporarily activates a minimal application menu only when needed. It is disabled under fullscreen/system-hidden menu bars and restores the prior application only if LessBar still owns focus. Temporary all-section reveal restores the prior normal collapsed state at expiry.

## System constraints

The width strategy is enabled on macOS 13–26, with macOS 27+ explicitly disabled pending a verified implementation. The separate reveal window is needed when macOS removes an oversized native item.

With Accessibility permission, sharing-control placement reads only Control Center's extras menu bar and the exact `com.apple.menuextra.audiovideo` identifier. Its inset AX bounds must match exactly one on-screen status window owned by Control Center. Ambiguous geometry, unavailable permission and unknown identifiers never produce a drag. The native boundary is not moved to another group.

Reordering runs only while expanded and with no mouse button, modifier or menu held. A pending close waits for this bounded handoff; the normal interaction policy is suspended during generated Command-drag events. User input interrupts the operation and allows a later retry after a short delay. The result is checked against fresh indicator/boundary geometry, not inferred from event delivery. Failure is reported in settings and is not retried continuously. Reopening settings permits another attempt. Display/Space changes and shutdown cancel the operation and release the generated drag.

The public bundle ID is `io.github.devnjw.LessBar`. The existing `TidyBar.Toggle` autosave key is retained to preserve placement. Only known setup/placement keys migrate from `local.tidybar.app`, once, without overwriting new choices. Login registration is not migrated between bundle identities.

## Verification

Run `swift test` for geometry, transient/permanent recovery failures, input handling and preference migration. Before a release, also verify:

- Repeated hide/show from the native chevron and settings; UI state stays synchronized.
- Sharing indicator visible before and after collapse; no overlapping recovery button.
- Recovery button receives the first click without window activation.
- Native right-click Settings/Quit menu, no custom spacing or separator.
- Display changes, notches, full-screen Spaces and multiple displays.
- Launch at Login from an installed copy, restart, quit and update.
- English/Korean resources from the packaged app, outside the source directory.
- Both Mach-O architectures, code signature, notarization and DMG contents.
