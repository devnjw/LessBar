# Releasing Less Bar

Release artifacts are built locally with a Developer ID Application certificate. CI only produces ad-hoc-signed development artifacts, never a public release. Signing identities and credentials are not stored in the repository.

## Mac App Store readiness

The current pipeline is for direct distribution, not Mac App Store submission. The review on 2026-10-18 found these release gates:

- No sandbox entitlements, Store archive/export configuration, or Store distribution signing setup is present. [Review guideline 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility) requires sandboxing. Apple [does not support assistive Accessibility APIs inside App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox), so adding an entitlement alone cannot make the current hover/click geometry and sharing-control behavior submission-ready. Validate a supported sandbox design before investing in Store packaging.
- Hiding is disabled on macOS 27+. Do not remove that safety gate without implementing and testing a compatible engine. Intel and older supported macOS versions also still need hardware testing.
- `Resources/Info.plist` has no `LSApplicationCategoryType`. There is no app privacy manifest. Audit UserDefaults and system-uptime usage against Apple's [required-reason API rules](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api); the legacy `local.tidybar.app` migration reads another defaults domain and needs separate consideration before declaring own-app-only defaults access.
- The README privacy summary is not a published privacy-policy flow. Provide a stable policy URL and an accessible in-app link, plus Store screenshots, localized product metadata, support/contact details, age rating, export-compliance answers and review instructions. Confirm privacy answers against the final binary.
- App Store Connect app records, agreements, tax/banking, pricing and regional business requirements were not verified because the available browser session required login. A local certificate does not prove these are complete.
- The review's signed test build passed 94 tests and universal packaging. Short `leaks` runs reported small `AXObserverCookie` allocations in both the test build (656 bytes in a follow-up scan) and the unchanged main build after comparable UI inspection (256 bytes). Their allocation origin and long-running growth are unresolved; these are not proof of an application-code regression or of leak-free behavior. Profile with allocation stacks and repeated UI/display/Space transitions. Test real screen sharing and permission loss; unit tests do not establish protection for every system indicator.

Do not describe a signed or notarized DMG as an App Store-approved build.

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
