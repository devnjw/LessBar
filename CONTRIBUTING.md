# Contributing

Less Bar is deliberately small. Please discuss new features in an issue before implementing them. Bug fixes, compatibility reports, accessibility improvements and translations are welcome.

Read [AGENTS.md](AGENTS.md) for product principles and [Architecture](docs/ARCHITECTURE.md) for the code structure.

Use Xcode 16+ / Swift 6+. Run `swift test` and `bash scripts/build-app.sh --universal`. Test the packaged app rather than only `swift run`: login items and localized resources depend on a real app bundle.

When reporting a bug, include macOS version, Mac architecture, display/notch setup, whether screen sharing was active, and steps to reproduce. Crop screenshots to avoid exposing private menu bar or screen contents.

Keep settings minimal, preserve native menus, keyboard and accessibility support, and retain a reliable way to reveal hidden icons. Do not add third-party dependencies without discussing the need.

Code contributions are under the repository's MIT license. Never commit signing certificates, passwords, API keys or notarization credentials.
