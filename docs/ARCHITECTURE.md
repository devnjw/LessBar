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
| `SettingsWindowController` | Top-anchored resizing, minimize/reopen and close lifecycle |
| `ApplicationMenuController` | Application activation policy and menu ownership |

## Collapse lifecycle

Capture the user's boundary before changing the native status-item width. Prepare independent nonactivating panels and validate placement on every display before collapsing. Show the panels without animation in the native chevron's current direction, collapse the native item, then flip the replacement chevrons immediately. This keeps a control visible across the transition without waiting for the first retry timer. Unknown or unsafe placement leaves the native item expanded. Never show a panel over an occupied system item.

During initial settling or an unsafe snapshot, check every 75 ms. A continuous unsafe interval of 750 ms triggers expansion. Once settled, check every 500 ms. A fresh safe sample clears the failure deadline. A display change reveals immediately.

Recovery panels follow each display's actual system menu bar. A 100 ms visibility poll and Space-change refresh hide panels when the full-width system menu bar is absent, transparent or sliding offscreen, including full-screen video and desktop auto-hide. Hidden menu bars keep the shared collapsed state without triggering recovery failure. When a menu bar returns, collision checks run before restoring its panel; other displays remain independent. Unknown visibility hides panels until a known visible menu bar returns. Queries inspect only window layers, bounds and alpha, requiring neither screen capture nor window titles.

The recovery controller owns its safety, retry and visibility timers. Revealing invalidates them, clears the session and removes the panel. Delayed clicks are checked against panel identity; cancelled retry callbacks are checked against timer identity. Recovery always reveals rather than toggles, preventing stale callbacks from collapsing a new session.

The engine is the source of truth for the published state. Native controls and hover use the same transition path. Settings and native menus have no show/hide action; only Quit has an app shortcut (⌘Q). Reopening LessBar remains the recovery route. The recovery timers only run while collapsed. The input coordinator samples pointer/modifier state every 50 ms and refreshes geometry every 200 ms; it never observes typed key content.

## Shared multi-display interaction

`InteractionPolicy` is a pure monotonic-time state machine. Preferences and visibility are shared by all displays; hover dwell resets when changing display. `MenuBarGeometry` excludes application-menu rectangles, status items and the notch. Hover detection uses Accessibility to read menu geometry; unknown geometry cannot trigger reveal.

`LengthMenuBarEngine` retains native boundaries and preserves their autosaved positions. Native content-width constraints and padding are synchronized for every retained mirrored window; setting NSStatusItem.length alone changes only the active display on the tested macOS 26 build. Invisible expanded boundaries use a one-point window. Native status windows are tracked through AppKit rather than owner PID, because Window Server reports them under Control Center. External collision checks exclude native window IDs or an exact matching frame.

`RecoveryController` creates one collision-checked panel per display and refuses partial display coverage. The chevron and recovery panels are hidden only when hover is enabled with Accessibility permission. Permission changes reconfigure native mirrors and collapsed recovery panels at the next geometry refresh. Visible panels still follow each display's system menu bar visibility. Display changes cancel stale work, reveal while layout settles, then restore the shared collapsed state. Reopening settings also reveals the icons for recovery.

The settings view exposes three switches and a collapsed Timing group with two delays. New installations default to click-the-chevron interaction, with hover off and automatic rehide on. Preferences makes automatic rehide effective whenever hover is on; its switch is on and disabled with an explanation, while the hide delay remains adjustable. The independent automatic-hide choice stays persisted and is restored when hover is turned off, including after relaunch. Rehide always waits for pointer exit. Empty-space click reveal and application-menu hiding are disabled, and Command editing stays available regardless of retired preference values. Existing hover, automatic-hide and delay choices are retained. Hover mode retains native right-click menus over empty menu bar space, native keyboard navigation and reopen recovery. The native boundary stays registered at its saved position with a one-point expanded window, and Command editing temporarily shows it.

An already-enabled always-hidden section retains its boundary placement and temporary-reveal context-menu action. Reopening settings temporarily reveals that section as well; expiry waits until settings, menus and drags are closed, then restores the previous normal collapsed state. New installations do not create the secondary section.

The entire Timing title row is clickable while the native disclosure retains keyboard and accessibility support. Timing sends its final layout height to `SettingsWindowController`, which owns sizing without intrinsic window constraints. Its hosting viewport reserves at least a screen's height even while collapsed, so SwiftUI never has to recenter overflowing content before reporting an expansion. Content stays pinned to the top and clipped at the bottom while the window height eases to its target over 220 ms. Reversing a transition starts from the current height, and Reduce Motion uses an immediate resize.

Opening Settings promotes the app to `.regular` before revealing icons and presenting the window. `ApplicationMenuController` retains this policy while Settings is open, including when minimized or inactive, so menu restoration cannot remove the app from Dock or ⌘Tab. The window close delegate returns to `.accessory`; reopening a minimized window deminiaturizes it. Closing Settings never terminates the menu bar engine.

## System constraints

The width strategy is enabled on macOS 13–26, with macOS 27+ explicitly disabled pending a verified implementation. The separate reveal window is needed when macOS removes an oversized native item.

With Accessibility permission, sharing-control placement reads only Control Center's extras menu bar and the exact `com.apple.menuextra.audiovideo` identifier. Its inset AX bounds must match exactly one on-screen status window owned by Control Center. Ambiguous geometry, unavailable permission and unknown identifiers never produce a drag. The native boundary is not moved to another group.

Reordering runs only while expanded and with no mouse button, modifier or menu held. A pending close waits for this bounded handoff; the normal interaction policy is suspended during generated Command-drag events. User input interrupts the operation and allows a later retry after a short delay. The result is checked against fresh indicator/boundary geometry, not inferred from event delivery. Failure is reported in settings and is not retried continuously. Reopening settings permits another attempt. Display/Space changes and shutdown cancel the operation and release the generated drag.

The public bundle ID is `io.github.devnjw.LessBar`. The existing `TidyBar.Toggle` autosave key is retained to preserve placement. Only known setup/placement keys migrate from `local.tidybar.app`, once, without overwriting new choices. Login registration is not migrated between bundle identities.

## Verification

Run `swift test` for geometry, transient/permanent recovery failures, input handling and preference migration. Before a release, also verify:

- Repeated hide/show from the native chevron and hover; UI state stays synchronized.
- Sharing indicator visible before and after collapse; no overlapping recovery button.
- Recovery button receives the first click without window activation.
- Native right-click Settings/Quit menu, no custom spacing or separator.
- Display changes, notches, full-screen Spaces and multiple displays.
- Launch at Login from an installed copy, restart, quit and update.
- English/Korean resources from the packaged app, outside the source directory.
- Both Mach-O architectures, code signature, notarization and DMG contents.
