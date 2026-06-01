import Darwin
import ShelfDropCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAILED: \(message)")
        exit(1)
    }
}

func doesNotTriggerAfterOnlyTwoFastTaps() {
    var detector = KeyTapDetector(requiredTapCount: 3, minimumInterval: 0.04, maximumInterval: 0.25)

    expect(detector.registerTap(at: 10.00) == false, "first tap should not trigger")
    expect(detector.registerTap(at: 10.10) == false, "second tap should not trigger")
}

func triggersOnThirdFastTapAndResets() {
    var detector = KeyTapDetector(requiredTapCount: 3, minimumInterval: 0.04, maximumInterval: 0.25)

    expect(detector.registerTap(at: 10.00) == false, "first tap should not trigger")
    expect(detector.registerTap(at: 10.10) == false, "second tap should not trigger")
    expect(detector.registerTap(at: 10.20) == true, "third tap should trigger")
    expect(detector.registerTap(at: 10.30) == false, "detector should reset after triggering")
}

func resetsWhenTapIntervalIsTooSlow() {
    var detector = KeyTapDetector(requiredTapCount: 3, minimumInterval: 0.04, maximumInterval: 0.25)

    expect(detector.registerTap(at: 10.00) == false, "first tap should not trigger")
    expect(detector.registerTap(at: 10.10) == false, "second tap should not trigger")
    expect(detector.registerTap(at: 10.50) == false, "slow third tap should reset")
    expect(detector.registerTap(at: 10.60) == false, "second tap after reset should not trigger")
    expect(detector.registerTap(at: 10.70) == true, "third fast tap after reset should trigger")
}

func resetsWhenTapIntervalIsTooFast() {
    var detector = KeyTapDetector(requiredTapCount: 3, minimumInterval: 0.04, maximumInterval: 0.25)

    expect(detector.registerTap(at: 10.00) == false, "first tap should not trigger")
    expect(detector.registerTap(at: 10.02) == false, "too-fast second tap should reset")
    expect(detector.registerTap(at: 10.12) == false, "second valid tap after reset should not trigger")
    expect(detector.registerTap(at: 10.22) == true, "third valid tap after reset should trigger")
}

doesNotTriggerAfterOnlyTwoFastTaps()
triggersOnThirdFastTapAndResets()
resetsWhenTapIntervalIsTooSlow()
resetsWhenTapIntervalIsTooFast()
print("KeyTapDetectorTests passed")
