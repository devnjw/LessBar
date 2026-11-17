import AppKit
import CoreFoundation
import NativePreferences

/// The system's app list is a property-list encoded dictionary represented by
/// alternating keys and values. Preserve unknown records and fields verbatim.
struct NativeAppList {
    private(set) var entries: [Any]

    init(data: Data) throws {
        guard let entries = try PropertyListSerialization.propertyList(from: data, format: nil) as? [Any],
              entries.count.isMultiple(of: 2) else { throw NativePreferencesError.invalidList }
        for index in stride(from: 1, to: entries.count, by: 2) {
            guard let record = entries[index] as? [String: Any],
                  record["isAllowed"] is Bool else { throw NativePreferencesError.invalidList }
        }
        self.entries = entries
    }

    static func bundle(in location: Any?) -> String? {
        ((location as? [String: Any])?["bundle"] as? [String: Any])?["_0"] as? String
    }

    var allBundleIdentities: Set<String> { identities(of: Set(allowed.keys)) }

    func identities(of owners: Set<String>) -> Set<String> {
        var identities: Set<String> = []
        for index in stride(from: 1, to: entries.count, by: 2) {
            guard let record = entries[index] as? [String: Any],
                  let bundle = Self.bundle(in: record["location"]), owners.contains(bundle) else { continue }
            identities.insert(bundle)
            identities.formUnion((record["menuItemLocations"] as? [Any] ?? []).compactMap { Self.bundle(in: $0) })
        }
        return identities
    }

    var allowed: [String: Bool] {
        var result: [String: Bool] = [:]
        for index in stride(from: 1, to: entries.count, by: 2) {
            guard let record = entries[index] as? [String: Any],
                  let owner = Self.bundle(in: record["location"]),
                  let allowed = record["isAllowed"] as? Bool else { continue }
            result[owner] = allowed
        }
        return result
    }

    /// Resolve helper bundles to the record macOS actually uses for that app.
    func owners(for bundles: Set<String>) -> Set<String> {
        var result: Set<String> = []
        for index in stride(from: 1, to: entries.count, by: 2) {
            guard let record = entries[index] as? [String: Any],
                  let owner = Self.bundle(in: record["location"]) else { continue }
            let locations = record["menuItemLocations"] as? [Any] ?? []
            let identities = Set(locations.compactMap { Self.bundle(in: $0) } + [owner])
            if !identities.isDisjoint(with: bundles) { result.insert(owner) }
        }
        return result
    }

    mutating func set(_ changes: [String: Bool]) {
        for index in stride(from: 1, to: entries.count, by: 2) {
            guard var record = entries[index] as? [String: Any],
                  let owner = Self.bundle(in: record["location"]), let value = changes[owner],
                  record["isAllowed"] as? Bool != value else { continue }
            record["isAllowed"] = value
            entries[index] = record
        }
    }

    func data() throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: entries, format: .binary, options: 0)
    }
}

enum NativePreferencesError: Error {
    case accessNeeded, invalidList, writeFailed, recoveryFailed
}

/// Uses the normal Menu Bar preferences, never an assessment-mode assertion.
/// A durable ownership record makes quitting and crash recovery restore only
/// changes made by Less Bar, rather than replacing the user's complete app list.
@MainActor
final class NativeMenuBarPreferences {
    nonisolated static let inputBundle = "com.apple.TextInputMenuAgent"
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist")
    }
    private let defaults: UserDefaults
    private var grantedURL: URL?
    private let bookmarkKey = "nativeMenuBarPreferencesBookmark"
    private let journalKey = "nativeMenuBarVisibilityJournal"
    private let inputDomain: CFString
    private let preferencesURL: URL

    struct Journal: Codable {
        var apps: [String: Bool] = [:]
        var inputChanged = false
        var inputValue: Bool? // nil means the original key was absent.
        var isEmpty: Bool { apps.isEmpty && !inputChanged }
    }

    init(defaults: UserDefaults = .standard, fileURL: URL = NativeMenuBarPreferences.fileURL,
         inputDomain: String = "com.apple.TextInputMenu") {
        self.defaults = defaults
        self.preferencesURL = fileURL
        self.inputDomain = inputDomain as CFString
        if let data = defaults.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                  relativeTo: nil, bookmarkDataIsStale: &stale),
               url.standardizedFileURL == Self.fileURL.standardizedFileURL {
                _ = url.startAccessingSecurityScopedResource()
                grantedURL = url
            }
        }
    }

    var hasAccess: Bool { (try? read()) != nil }
    var allBundleIdentities: Set<String> { (try? read().allBundleIdentities) ?? [] }
    func restrictionExclusions(hidden: Set<String>, visible: Set<String>) -> Set<String> {
        guard let list = try? read() else { return hidden }
        let hiddenOwners = list.owners(for: hidden).subtracting(list.owners(for: visible))
        return list.identities(of: hiddenOwners).union(hidden.subtracting(list.allBundleIdentities))
    }
    private var preferenceChannel: UserDefaults?
    private func channel() throws -> UserDefaults {
        if let preferenceChannel { return preferenceChannel }
        let file = grantedURL ?? preferencesURL
        let container = file.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var failure: NSError?
        guard let created = LBCreateContainerPreferences(file.deletingPathExtension().lastPathComponent,
                                                        container, &failure) else {
            if let failure { throw failure }
            throw NativePreferencesError.accessNeeded
        }
        preferenceChannel = created
        return created
    }

    func requestAccess(_ completion: @escaping @MainActor (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.title = L10n.nativePreferencesTitle
        panel.message = L10n.nativePreferencesExplanation
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Self.fileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = Self.fileURL.lastPathComponent
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url,
                  url.standardizedFileURL == Self.fileURL.standardizedFileURL else { completion(false); return }
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil)
                _ = url.startAccessingSecurityScopedResource()
                grantedURL = url
                _ = try read()
                defaults.set(bookmark, forKey: bookmarkKey)
                try restore(releaseOwnership: true)
                completion(true)
            } catch { completion(false) }
        }
    }

    private func read() throws -> NativeAppList {
        // Check the explicit file grant, then read the authoritative container
        // domain. Absolute-path CFPreferences creates a separate cache alias.
        _ = try Data(contentsOf: grantedURL ?? preferencesURL)
        let defaults = try channel()
        guard defaults.synchronize(), let data = defaults.data(forKey: "trackedApplications") else {
            throw NativePreferencesError.accessNeeded
        }
        return try NativeAppList(data: data)
    }

    private func write(_ list: NativeAppList) throws {
        let defaults = try channel()
        defaults.set(try list.data(), forKey: "trackedApplications")
        guard defaults.synchronize(), try read().allowed == list.allowed else {
            throw NativePreferencesError.writeFailed
        }
    }

    private func journal() throws -> Journal {
        guard let data = defaults.data(forKey: journalKey) else { return Journal() }
        // An unreadable ownership record must never be silently overwritten.
        return try JSONDecoder().decode(Journal.self, from: data)
    }

    private func save(_ journal: Journal) throws {
        if journal.isEmpty { defaults.removeObject(forKey: journalKey) }
        else { defaults.set(try JSONEncoder().encode(journal), forKey: journalKey) }
        guard defaults.synchronize() else { throw NativePreferencesError.writeFailed }
    }

    func hide(bundles: Set<String>, keepingVisible visible: Set<String> = []) throws {
        var record = try journal()
        var list = try read()
        let owners = list.owners(for: bundles).subtracting(list.owners(for: visible))
        for owner in owners where record.apps[owner] == nil && list.allowed[owner] == true {
            record.apps[owner] = true
        }
        if bundles.contains(Self.inputBundle), !record.inputChanged {
            record.inputValue = CFPreferencesCopyAppValue("visible" as CFString, inputDomain) as? Bool
            record.inputChanged = record.inputValue != false
        }
        // Retain the original values across every reveal/hide in this session.
        // A transient off value must never replace the known original on value.
        try save(record)
        do {
            let changes = Dictionary(uniqueKeysWithValues: record.apps.map {
                ($0.key, owners.contains($0.key) ? false : $0.value)
            }).filter { list.allowed[$0.key] != $0.value }
            list.set(changes)
            if !changes.isEmpty { try write(list) }
            if record.inputChanged {
                try setInputVisible(bundles.contains(Self.inputBundle) ? false : record.inputValue)
            }
        } catch {
            try? restore()
            throw error
        }
    }

    private func setInputVisible(_ visible: Bool?) throws {
        CFPreferencesSetAppValue("visible" as CFString, visible.map { NSNumber(value: $0) }, inputDomain)
        guard CFPreferencesAppSynchronize(inputDomain) else { throw NativePreferencesError.writeFailed }
    }

    func restore(releaseOwnership: Bool = false) throws {
        let record = try journal()
        guard !record.isEmpty else { return }
        if !record.apps.isEmpty {
            var list = try read()
            // Merge against the current list, preserving unrelated user changes.
            let changes = record.apps.filter { list.allowed[$0.key] == false }
            list.set(changes)
            if !changes.isEmpty { try write(list) }
        }
        if record.inputChanged { try setInputVisible(record.inputValue) }
        if releaseOwnership { try save(Journal()) }
    }
}
