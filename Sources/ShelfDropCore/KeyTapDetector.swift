import Foundation

public struct KeyTapDetector {
    private let requiredTapCount: Int
    private let minimumInterval: TimeInterval
    private let maximumInterval: TimeInterval
    private var lastTapTime: TimeInterval?
    private var tapCount = 0

    public init(requiredTapCount: Int, minimumInterval: TimeInterval, maximumInterval: TimeInterval) {
        self.requiredTapCount = requiredTapCount
        self.minimumInterval = minimumInterval
        self.maximumInterval = maximumInterval
    }

    public mutating func registerTap(at time: TimeInterval) -> Bool {
        defer { lastTapTime = time }

        guard let lastTapTime else {
            tapCount = 1
            return false
        }

        let interval = time - lastTapTime
        guard interval >= minimumInterval && interval <= maximumInterval else {
            tapCount = 1
            return false
        }

        tapCount += 1
        if tapCount >= requiredTapCount {
            reset()
            return true
        }

        return false
    }

    public mutating func registerModifierChange(
        isTargetOnly: Bool,
        hasAnyModifier: Bool,
        at time: TimeInterval
    ) -> Bool {
        if isTargetOnly {
            return registerTap(at: time)
        }

        if hasAnyModifier {
            reset()
        }

        return false
    }

    public mutating func reset() {
        lastTapTime = nil
        tapCount = 0
    }
}
