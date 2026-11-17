import AppKit
import NativeVisibility

/// A scoped restriction for the original system AV item. This intentionally
/// also suppresses macOS's other assessment-sensitive controls while held.
/// The user has accepted that tradeoff for an AV item in the hidden section.
@MainActor
final class RecordingIndicatorRestriction {
    typealias Completion = @MainActor (AnyObject?, Bool) -> Void
    typealias Activate = @MainActor ([String], @escaping Completion) -> Void
    private let activate: Activate
    private let invalidate: @MainActor (AnyObject) -> Void
    private var assertion: AnyObject?
    private var allowed: Set<String> = []
    private var generation = 0
    private(set) var isPending = false
    var isActive: Bool { assertion != nil }

    init(activate: @escaping Activate = { bundles, completion in
        HBNativeVisibilityActivate((0...255).map { NSNumber(value: $0) }, bundles) { result, error in
            MainActor.assumeIsolated { completion(result as AnyObject?, error == nil && result != nil) }
        }
    }, invalidate: @escaping @MainActor (AnyObject) -> Void = { HBNativeVisibilityInvalidate($0) }) {
        self.activate = activate
        self.invalidate = invalidate
    }

    func apply(hidden: Bool, allowing bundles: Set<String>, completion: @escaping @MainActor (Bool) -> Void) {
        if !hidden {
            release()
            completion(true)
            return
        }
        if isActive && allowed == bundles { completion(true); return }
        guard !isPending else { completion(false); return }
        generation += 1
        let token = generation
        isPending = true
        let invalidate = self.invalidate
        activate(bundles.sorted()) { [weak self] result, succeeded in
            guard let self else {
                if let result { invalidate(result) }
                return
            }
            guard generation == token else {
                if let result { invalidate(result) }
                return
            }
            isPending = false
            guard succeeded, let result else {
                if let result { invalidate(result) }
                completion(false)
                return
            }
            let old = assertion
            assertion = result
            allowed = bundles
            if let old { invalidate(old) }
            completion(true)
        }
    }

    func release() {
        generation += 1
        isPending = false
        if let assertion { invalidate(assertion) }
        assertion = nil
        allowed = []
    }
}
