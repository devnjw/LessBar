import Foundation

/// Window Server snapshots can lag behind the status item's length change.
/// Allow bounded retries without ever displaying a control over a system item.
struct LayoutRecovery {
    enum Action: Equatable { case monitor, retry, reveal }

    static let retryInterval: TimeInterval = 0.075
    static let graceInterval: TimeInterval = 0.75
    private let settlingUntil: TimeInterval
    private var unsafeSince: TimeInterval?

    init(now: TimeInterval) {
        settlingUntil = now + Self.graceInterval
        unsafeSince = now
    }

    mutating func evaluate(controlIsSafe: Bool, now: TimeInterval) -> Action {
        if controlIsSafe {
            unsafeSince = nil
            return now < settlingUntil ? .retry : .monitor
        }
        let failureStart = unsafeSince ?? now
        unsafeSince = failureStart
        return now - failureStart >= Self.graceInterval ? .reveal : .retry
    }
}
