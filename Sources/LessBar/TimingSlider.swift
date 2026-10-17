import AppKit
import SwiftUI

/// A native slider without dense tick marks; mouse, keyboard and VoiceOver all
/// retain the same tenth-of-a-second precision as the timing preferences.
struct TimingSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let title: String
    let formattedValue: String
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> TimingSliderControl {
        let slider = TimingSliderControl()
        slider.target = slider
        slider.action = #selector(TimingSliderControl.changed)
        slider.isContinuous = true
        slider.numberOfTickMarks = 0
        return slider
    }

    func updateNSView(_ slider: TimingSliderControl, context: Context) {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.step = step
        slider.doubleValue = value
        slider.isEnabled = isEnabled
        slider.setAccessibilityLabel(title)
        slider.setAccessibilityValueDescription(formattedValue)
        slider.onChange = { value = $0 }
    }
}

final class TimingSliderControl: NSSlider {
    var step = 0.1
    var onChange: ((Double) -> Void)?

    @objc func changed() {
        doubleValue = min(maxValue, max(minValue, (doubleValue / step).rounded() * step))
        onChange?(doubleValue)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 125: adjust(-step)
        case 124, 126: adjust(step)
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformIncrement() -> Bool { adjust(step) }
    override func accessibilityPerformDecrement() -> Bool { adjust(-step) }

    @discardableResult private func adjust(_ delta: Double) -> Bool {
        guard isEnabled else { return false }
        doubleValue += delta
        changed()
        return true
    }
}
