import Foundation

/// Exactly one mechanism hides ordinary app icons in a transition. Combining
/// preference hiding and an assessment reflow makes the same icons animate twice.
struct NativeCollapsePlan: Equatable {
    let restrictSystemItems: Bool
    let preferenceHiddenBundles: Set<String>
    let restrictionAllowedBundles: Set<String>

    init(hidden: Set<String>, allBundles: Set<String>, resolvedHidden: Set<String>,
         recordingOnHiddenSide: Bool) {
        restrictSystemItems = recordingOnHiddenSide
        preferenceHiddenBundles = recordingOnHiddenSide
            ? hidden.intersection(["com.apple.TextInputMenuAgent"]) : hidden
        restrictionAllowedBundles = allBundles.subtracting(resolvedHidden)
    }
}
