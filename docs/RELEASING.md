# Releasing Less Bar

Release artifacts are built locally with a Developer ID Application certificate. CI only produces ad-hoc-signed development artifacts, never a public release. Signing identities and credentials are not stored in the repository.

## One-time setup

Install a Developer ID Application certificate in Keychain. Check it with:

```sh
security find-identity -v -p codesigning
```

Create an [Apple app-specific password](https://support.apple.com/en-us/102654) for the developer account, then store it interactively in Keychain (do not put the password in shell history or chat):

```sh
xcrun notarytool store-credentials lessbar-notary --team-id YOUR_TEAM_ID
```

See Apple's [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Build and notarize

Update both version fields in `Resources/Info.plist`, run the automated tests and complete the manual checks in [Architecture](ARCHITECTURE.md). Then:

```sh
swift test
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAM_ID)' \
NOTARY_PROFILE=lessbar-notary \
bash scripts/package-release.sh --notarize
```

The script builds both architectures, embeds localization resources, signs with hardened runtime and a secure timestamp, submits the app for notarization, staples and validates its ticket, creates a drag-to-Applications DMG, then notarizes/staples the DMG. It produces a DMG, ZIP and `SHA256SUMS.txt` under `dist/release`. Notarization logs stay local. Any validation or signing failure stops the script.

If Apple's service times out, inspect the submission ID in the local log with `xcrun notarytool info`. Do not publish until the accepted ticket is stapled. A deliberately unnotarized preview can be built with `--preview`; filenames carry `unnotarized`, and release notes must disclose that Gatekeeper may block launch.

## Publish

Use the tested commit, create its version tag, and upload only the DMG, ZIP and checksums to a draft GitHub release. Verify the asset list, checksums, signing/notarization status and support notes before publishing. Early versions should be marked as pre-releases. Do not upload certificates, keychain profiles, intermediate logs or development artifacts as a notarized release.

The installation flow is: download DMG → drag to Applications → open Less Bar. Test this from a copy outside the source checkout. Confirm `spctl --assess --type execute --verbose "/path/to/Less Bar.app"` reports acceptance for the notarized build. Also verify `xcrun stapler validate` on both the app and DMG.

There is no automatic updater. Users quit the old app before replacing it. For the display-name change, replace an older `LessBar.app` with `Less Bar.app` rather than keeping both; the bundle identity stays the same. Prototype users moving from `local.tidybar.app` must re-enable Launch at Login for the public bundle ID.
