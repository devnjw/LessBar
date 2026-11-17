import XCTest
import CoreFoundation
import NativePreferences
@testable import LessBar

final class NativeMenuBarPreferencesTests: XCTestCase {
    private func location(_ bundle: String) -> [String: Any] { ["bundle": ["_0": bundle]] }
    private func listData() throws -> Data {
        let entries: [Any] = [
            location("hidden.app"), ["location": location("hidden.app"),
                "menuItemLocations": [location("hidden.helper")], "isAllowed": true, "future": "preserve"],
            location("user.disabled"), ["location": location("user.disabled"), "isAllowed": false],
            ["adhocBinary": ["_0": ["relative": "file:///test/helper"]]],
            ["location": ["adhocBinary": ["_0": ["relative": "file:///test/helper"]]], "isAllowed": true]
        ]
        return try PropertyListSerialization.data(fromPropertyList: entries, format: .binary, options: 0)
    }

    func testRealDictionaryEncodingAndHelperIdentityPreserveUnknownRecords() throws {
        var list = try NativeAppList(data: listData())
        XCTAssertEqual(list.owners(for: ["hidden.helper"]), ["hidden.app"])
        let original = list.entries
        list.set(["hidden.app": false])
        XCTAssertEqual(list.allowed, ["hidden.app": false, "user.disabled": false])
        XCTAssertEqual((list.entries[1] as? [String: Any])?["future"] as? String, "preserve")
        XCTAssertEqual(list.entries[5] as? NSDictionary, original[5] as? NSDictionary)
        XCTAssertEqual(try NativeAppList(data: list.data()).allowed, list.allowed)
    }

    @MainActor func testNativeWriteAndCrashRecoveryMergeOnlyOwnedSettings() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LessBarNativePreferences-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let preferencesFolder = folder.appendingPathComponent("Library/Preferences")
        try FileManager.default.createDirectory(at: preferencesFolder, withIntermediateDirectories: true)
        let file = preferencesFolder.appendingPathComponent("controlcenter.plist")
        let root: [String: Any] = ["trackedApplications": try listData(), "unrelated": "keep"]
        try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0).write(to: file)
        let suite = "LessBarTests.nativePreferences.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let inputDomain = folder.appendingPathComponent("input").path
        let preferences = NativeMenuBarPreferences(defaults: defaults, fileURL: file, inputDomain: inputDomain)
        XCTAssertTrue(preferences.hasAccess)
        try preferences.hide(bundles: ["hidden.helper", NativeMenuBarPreferences.inputBundle])
        func read() throws -> NativeAppList {
            let root = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as? [String: Any])
            XCTAssertEqual(root["unrelated"] as? String, "keep")
            return try NativeAppList(data: XCTUnwrap(root["trackedApplications"] as? Data))
        }
        XCTAssertEqual(try read().allowed["hidden.app"], false)
        XCTAssertEqual(CFPreferencesCopyAppValue("visible" as CFString, inputDomain as CFString) as? Bool, false)
        XCTAssertNotNil(defaults.data(forKey: "nativeMenuBarVisibilityJournal"))
        try preferences.restore()
        XCTAssertNotNil(defaults.data(forKey: "nativeMenuBarVisibilityJournal"),
            "Ordinary reveal must retain the known original values")
        // Replay a delayed off value from another writer after a reveal. The
        // next collapse must not mistake it for the user's original preference.
        let native = try XCTUnwrap(LBCreateContainerPreferences("controlcenter", folder, nil))
        var delayed = try read()
        delayed.set(["hidden.app": false])
        native.set(try delayed.data(), forKey: "trackedApplications")
        XCTAssertTrue(native.synchronize())
        try preferences.hide(bundles: ["hidden.helper"])
        // New controller instance simulates recovery after the process died.
        let recovered = NativeMenuBarPreferences(defaults: defaults, fileURL: file, inputDomain: inputDomain)
        try recovered.restore(releaseOwnership: true)
        XCTAssertEqual(try read().allowed, ["hidden.app": true, "user.disabled": false])
        XCTAssertNil(CFPreferencesCopyAppValue("visible" as CFString, inputDomain as CFString))
        XCTAssertNil(defaults.data(forKey: "nativeMenuBarVisibilityJournal"))
        try recovered.restore() // Recovery is idempotent.
    }

    @MainActor func testUnreadableRecoveryRecordPreventsNewChanges() throws {
        let suite = "LessBarTests.nativePreferences.corrupt.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let damaged = Data("unreadable".utf8)
        defaults.set(damaged, forKey: "nativeMenuBarVisibilityJournal")
        let preferences = NativeMenuBarPreferences(defaults: defaults,
            fileURL: URL(fileURLWithPath: "/private/tmp/nonexistent-lessbar-test.plist"))
        XCTAssertThrowsError(try preferences.hide(bundles: ["app"]))
        XCTAssertEqual(defaults.data(forKey: "nativeMenuBarVisibilityJournal"), damaged)
    }

    func testMalformedSystemListCannotBecomeAnEmptyAllowList() throws {
        let malformed = try PropertyListSerialization.data(fromPropertyList: ["unknown"], format: .binary, options: 0)
        XCTAssertThrowsError(try NativeAppList(data: malformed))
    }
}
