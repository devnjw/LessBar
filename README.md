<p align="center"><img src="Resources/Brand/lessbar-app-icon-1024.png" width="112" alt="LessBar"></p>
<h1 align="center">LessBar</h1>
<p align="center">A little less in your Mac menu bar.</p>
<p align="center"><a href="https://github.com/devnjw/LessBar/releases">Download</a> · <a href="docs/README.ko.md">한국어</a> · <a href="https://github.com/devnjw/LessBar/issues">Report a bug</a></p>

Hide the icons to the left of a single chevron. Click again to show them. No separators, accounts, subscriptions or extra panels to configure.

## Install

1. Download the **universal `.dmg`** from [Releases](https://github.com/devnjw/LessBar/releases). It includes Apple Silicon and Intel builds. Choose the DMG under **Assets**, not GitHub's source-code archive.
2. Open it and drag **LessBar** to **Applications**.
3. Open LessBar from Applications. There is no Dock icon; look for **›** in the menu bar.

The release notes state whether a build is Apple-notarized. A file labeled **unnotarized** is a developer preview and may be blocked by macOS. Prefer a notarized release; do not disable Gatekeeper. Developers can also [build from source](#build-from-source).

**Requirements:** macOS 13–26. Hiding is disabled on macOS 27 and later. Currently tested interactively on macOS 26.6.2 / Apple Silicon; Intel binaries are built, but Intel hardware and older macOS versions still need testing.

## Use

- While expanded, hold **⌘ Command** and drag the chevron to your preferred boundary.
- Click the chevron to hide/show icons on its left. Icons on its right stay visible.
- Right-click it for **Settings** and **Quit**. Settings has one hide/show action and **Launch at Login**.

English and Korean follow your macOS language preference. Closing the settings window keeps LessBar running. To update, quit LessBar, replace the app in Applications, then reopen it. There is no automatic updater.

## Recovery and limits

Reopen LessBar from Applications to show all icons and open settings. Quitting restores hidden icons. Display changes also return to the expanded state.

LessBar checks for menu bar overlap and moves its reveal button away from other items, including active screen-sharing indicators. It briefly retries during system layout changes and expands if a safe position cannot be found. Expanded-state ordering of system indicators is controlled by macOS.

This is an early release using a status item's width to hide neighbors. Notched displays can still run out of space; LessBar does not copy icons into a second bar. Multiple displays, full-screen Spaces and older systems need further testing. It cannot restore icons disabled in another app's preferences.

## Privacy

No analytics, network requests, account, Accessibility prompt or Screen Recording prompt. The app reads menu bar window geometry, not window images or titles. Launch at Login is opt-in and managed by macOS.

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
