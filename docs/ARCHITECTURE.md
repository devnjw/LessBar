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
| `Preferences` | ServiceManagement login registration and narrow preference migration |
| `SettingsView` / `L10n` | Minimal settings UI and English/Korean resources |

## Collapse lifecycle

Capture the user's boundary before changing the native status-item width. Prepare an independent nonactivating panel, collapse the native item, then validate placement before showing the reveal button. Never show the panel over an occupied system item.

During initial settling or an unsafe snapshot, check every 75 ms. A continuous unsafe interval of 750 ms triggers expansion. Once settled, check every 500 ms. A fresh safe sample clears the failure deadline. A display change reveals immediately.

The recovery controller owns both timers. Revealing invalidates them, clears the session and removes the panel. Delayed clicks are checked against panel identity; cancelled retry callbacks are checked against timer identity. Recovery always reveals rather than toggles, preventing stale callbacks from collapsing a new session.

The engine is the source of truth for the published state. Both native and settings controls use the same transition path. Timers only run while collapsed.

## System constraints

The width strategy is enabled on macOS 13–26, with macOS 27+ explicitly disabled pending a verified implementation. The separate reveal window is needed when macOS removes an oversized native item. Public status-item APIs do not provide a verified way to enforce sharing-indicator order in expanded mode.

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
