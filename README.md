<p align="center"><img src="Resources/Brand/lessbar-app-icon-1024.png" width="112" alt="Less Bar"></p>
<h1 align="center">Less Bar</h1>
<p align="center">A little less in your Mac menu bar.</p>
<p align="center"><a href="https://github.com/devnjw/LessBar/releases">Download</a> · <a href="docs/README.ko.md">한국어</a> · <a href="https://github.com/devnjw/LessBar/issues">Report a bug</a></p>

Hide menu bar icons, then reveal them with the arrow or by hovering over or clicking empty menu bar space.

## Install

1. Download the **universal `.dmg`** from [Releases](https://github.com/devnjw/LessBar/releases). It includes Apple Silicon and Intel builds. Choose the DMG under **Assets**, not GitHub's source-code archive.
2. Open it and drag **Less Bar** to **Applications**.
3. Open Less Bar from Applications and configure it in the settings window. There is no Dock icon; reopen the app from Applications or Raycast to return to settings.

The release notes state whether a build is Apple-notarized. A file labeled **unnotarized** is a developer preview and may be blocked by macOS. Prefer a notarized release; do not disable Gatekeeper. Developers can also [build from source](#build-from-source).

**Requirements:** macOS 13–26. Hiding is disabled on macOS 27 and later. Currently tested interactively on macOS 26.6.2 / Apple Silicon; Intel binaries are built, but Intel hardware and older macOS versions still need testing.

## Use

- Hold **⌘ Command** over the menu bar to reveal all sections and their boundaries, then drag icons across a boundary to choose which ones are hidden. Rearranging is always available; no setting is required.
- Click the arrow to reveal or hide icons whenever it is shown. Right-click it for **Settings**, **How to Use** and **Quit**.
- Enable **Hover to Show Icons**, **Click Empty Space to Show Icons**, or both. **Show Arrow** is independent. Without Accessibility permission, the arrow stays available. Right-click empty menu bar space for the same native menu.
- Reopen Less Bar from Applications or Raycast for settings, to change settings such as **Launch at Login**.

Expand **Language** in Settings and select **System Default**, **English**, or **한국어** using the radio buttons. Changes apply immediately and persist across launches; System Default follows your macOS language preference. While Settings is open, including when minimized, Less Bar appears in the Dock and ⌘Tab. Closing Settings returns to menu-bar-only mode and keeps Less Bar running. To update, quit Less Bar, replace the app in Applications, then reopen it. If the older copy is named `LessBar.app`, replace it with `Less Bar.app` and keep only one installed copy. There is no automatic updater.

## Recovery and limits

Reopen Less Bar from Applications to show all icons and open settings. Quitting restores hidden icons. Display changes briefly expand the icons while layout settles, then restore the previous shared visibility state.

With Accessibility access, Less Bar automatically moves the active screen-sharing control into the always-visible section to the right of its arrow. It leaves controls that are already on the right in place. If macOS rejects the move, settings show a message and the control stays visible; reopening Less Bar retries it.

Less Bar also checks for menu bar overlap and moves its reveal button away from other items. It briefly retries during system layout changes and expands if a safe position cannot be found.

This is an early release using a status item's width to hide neighbors. Notched displays can still run out of space; Less Bar does not copy icons into a second bar. Visibility is synchronized across native menu bars; full-screen Spaces, notched or differently arranged displays, Intel hardware and older systems still need further interactive testing. It cannot restore icons disabled in another app's preferences.

## Privacy

No analytics, network requests, account or Screen Recording access. Accessibility access identifies the system screen-sharing control and reorders it using Command-drag events. Empty-space hover and click detection use the same permission to read application-menu positions and sizes. The app reads menu bar identifiers and geometry without capturing images or titles. Launch at Login is opt-in and managed by macOS.

## Build from source

Requires Xcode 16 or newer (Swift 6+) with its command-line tools selected.

```sh
git clone https://github.com/devnjw/LessBar.git
cd LessBar
swift test
bash scripts/build-app.sh
open "dist/Less Bar.app"
```

For both Mac architectures:

```sh
bash scripts/build-app.sh --universal
```

Local builds are ad-hoc signed. Move the app to `/Applications` or `~/Applications` before enabling Launch at Login. Do not run multiple copies at once.

See [Architecture](docs/ARCHITECTURE.md), [Contributing](CONTRIBUTING.md) and [Release instructions](docs/RELEASING.md).

## License

[MIT](LICENSE). The repository and initial preview are available at no charge.

## Settings

Use the arrow or hover to reveal icons. The native menu provides **Settings**, **How to Use** and **Quit**; only Quit has a shortcut (**⌘Q**). Reopening Less Bar still reveals icons for recovery.

The window starts with **Launch at Login** and **Show Arrow**, followed by evenly spaced **Advanced**, **Language** and **How to Use** disclosures. **Advanced** contains **Hover to Show Icons**, **Click Empty Space to Show Icons**, **Automatically Hide**, and the timing sliders. Turning Show Arrow off opens Advanced automatically; you can fold it again. Language stays below Advanced. New installs show the arrow, disable both empty-space methods, and enable automatic hiding. When the arrow is shown, either, both or neither method can be on. Hiding it with both off enables Click; the final enabled method cannot be turned off until another method or the arrow is enabled.

Hover or a hidden arrow keeps Automatically Hide on and disabled. The independent automatic-hide choice is restored when the arrow is shown with hover off, including across relaunches. Upgrades preserve the previous arrow appearance and hover preference.

Click the **Advanced** title row or arrow to expand it. **Timing** is always visible inside Advanced, without another disclosure. The window grows smoothly downward with its top edge fixed. Adjust the hover delay (0–2 seconds) and hide delay (0–10 seconds), both in 0.1-second steps. Each control is enabled when its corresponding feature is on. Automatic hiding starts after the pointer leaves the menu bar and waits while a menu, drag, or settings window is active. Zero hides as soon as those interactions finish.

Choose **How to Use** in the right-click menu to open Settings with the guide expanded, or expand the bottom **How to Use** row for a short animation of Command-drag placement and the enabled reveal methods. Compact menu-bar examples loop seamlessly while visible: placement drags an icon left, hides it, reveals it and drags it back. Descriptions sit above the examples. Reduce Motion uses static illustrations. The examples do not change real icons.

The arrow hides only when **Show Arrow** is off and Accessibility permission is available. Losing permission restores it. Command-drag editing temporarily displays the boundaries. Application-menu hiding remains disabled. All native menu bars share one visibility state, with per-display collision checks and recovery controls.

Upgrades preserve an already-enabled always-hidden section and its placement. Right-click the arrow or empty menu bar space and choose **Show all sections temporarily**, or reopen Less Bar, to recover those items. Command-drag can move them back into the normal hidden or always-visible section. New installs do not create an always-hidden section.
