import Foundation

actor TwelveDataRateLimiter {
    static let shared = TwelveDataRateLimiter()

    // Twelve Data Basic: 8 API credits/minute.
    // 8.2 seconds gives a small safety margin and serializes all callers.
    private let minimumSpacing: TimeInterval = 8.2
    private var nextAllowedAt = Date.distantPast

    private init() {}

    func waitForTurn() async throws {
        let now = Date()
        let scheduledAt = max(now, nextAllowedAt)

        // Reserve the next slot before suspending. This matters because
        // Swift actors are re-entrant across await points.
        nextAllowedAt = scheduledAt.addingTimeInterval(
            minimumSpacing
        )

        let delay = scheduledAt.timeIntervalSince(now)

        guard delay > 0 else {
            return
        }

        let nanoseconds = UInt64(
            delay * 1_000_000_000
        )

        try await Task.sleep(
            nanoseconds: nanoseconds
        )
    }

    func deferRequests(
        for seconds: TimeInterval
    ) {
        let safeDelay = max(seconds, minimumSpacing)
        let candidate = Date().addingTimeInterval(
            safeDelay
        )

        if candidate > nextAllowedAt {
            nextAllowedAt = candidate
        }
    }
}
