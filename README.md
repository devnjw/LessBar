<p align="center"><img src="Resources/Brand/lessbar-app-icon-1024.png" width="112" alt="LessBar"></p>
<h1 align="center">LessBar</h1>
<p align="center">A little less in your Mac menu bar.</p>
<p align="center"><a href="https://github.com/devnjw/LessBar/releases">Download</a> · <a href="docs/README.ko.md">한국어</a> · <a href="https://github.com/devnjw/LessBar/issues">Report a bug</a></p>

Hide menu bar icons with an invisible boundary, then reveal them by hovering over or clicking an empty area of the menu bar. A clickable chevron is optional.

## Install

1. Download the **universal `.dmg`** from [Releases](https://github.com/devnjw/LessBar/releases). It includes Apple Silicon and Intel builds. Choose the DMG under **Assets**, not GitHub's source-code archive.
2. Open it and drag **LessBar** to **Applications**.
3. Open LessBar from Applications and configure it in the settings window. There is no Dock icon; reopen the app from Applications or Raycast to return to settings.

The release notes state whether a build is Apple-notarized. A file labeled **unnotarized** is a developer preview and may be blocked by macOS. Prefer a notarized release; do not disable Gatekeeper. Developers can also [build from source](#build-from-source).

**Requirements:** macOS 13–26. Hiding is disabled on macOS 27 and later. Currently tested interactively on macOS 26.6.2 / Apple Silicon; Intel binaries are built, but Intel hardware and older macOS versions still need testing.

## Use

- Hold **⌘ Command** over the menu bar to reveal all sections and their boundaries, then drag icons across a boundary to choose which ones are hidden. This editing behavior can be disabled in Advanced settings.
- Hover over or click an empty menu bar area to reveal hidden icons. Grant Accessibility access from settings to enable empty-area detection.
- Enable **Show section dividers** for a clickable chevron. Right-click a divider or an empty menu bar area for **Settings** and **Quit**.
- Reopen LessBar from Applications or Raycast for settings, including the hide/show action and **Launch at Login**.

English and Korean follow your macOS language preference. Closing the settings window keeps LessBar running. To update, quit LessBar, replace the app in Applications, then reopen it. There is no automatic updater.

## Recovery and limits

Reopen LessBar from Applications to show all icons and open settings. Quitting restores hidden icons. Display changes briefly expand the icons while layout settles, then restore the previous shared visibility state.

With Accessibility access, LessBar automatically moves the active screen-sharing control into the always-visible section to the right of its chevron. It leaves controls that are already on the right in place. If macOS rejects the move, settings show a message and the control stays visible; reopening LessBar retries it.

LessBar also checks for menu bar overlap and moves its reveal button away from other items. It briefly retries during system layout changes and expands if a safe position cannot be found.

This is an early release using a status item's width to hide neighbors. Notched displays can still run out of space; LessBar does not copy icons into a second bar. Visibility is synchronized across native menu bars; full-screen Spaces, notched or differently arranged displays, Intel hardware and older systems still need further interactive testing. It cannot restore icons disabled in another app's preferences.

## Privacy

No analytics, network requests, account or Screen Recording access. Accessibility access identifies the system screen-sharing control and reorders it using Command-drag events. Empty-area click and hover use the same permission to read application-menu positions and sizes. The app reads menu bar identifiers and geometry without capturing images or titles. Launch at Login is opt-in and managed by macOS.

## Build from source

Requires Xcode 16 or newer (Swift 6+) with its command-line tools selected.

```sh
git clone https://github.com/devnjw/LessBar.git
cd LessBar
swift test
bash scripts/build-app.sh
open dist/LessBar.app
```

For both Mac architectures:

```sh
bash scripts/build-app.sh --universal
```

Local builds are ad-hoc signed. Move the app to `/Applications` or `~/Applications` before enabling Launch at Login. Do not run multiple copies at once.

See [Architecture](docs/ARCHITECTURE.md), [Contributing](CONTRIBUTING.md) and [Release instructions](docs/RELEASING.md).

## License

[MIT](LICENSE). The repository and initial preview are available at no charge.

## Reveal preferences

Settings provide reveal on an empty-space click or hover, configurable hover delay, timed or pointer-exit rehide, optional dividers, Command-drag editing, an optional always-hidden section with temporary reveal, and optional application-menu hiding when space is limited. Click and hover need Accessibility access to distinguish application menus from empty space. No screen-recording access is requested.

Visibility is shared across all available native menu bars. On macOS 26, native mirrored windows receive the same width and each display has its own collision-checked recovery control when dividers are enabled. With dividers off, invisible boundaries occupy at most one point rather than leaving a button-sized gap. Reopen LessBar from Applications or Raycast to access settings.

Rehide delay ranges from 0 to 10 seconds in 0.1-second steps. Zero hides immediately when the selected rehide condition is reached and no menu or drag is active.
