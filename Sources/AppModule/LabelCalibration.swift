import Foundation

enum LabelCalibrationPolicyKind: String, Codable, Sendable {
    case fixed
    case atrAdaptive = "atr_adaptive"
}

struct LabelCalibrationPolicy: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: LabelCalibrationPolicyKind
    let horizonMinutes: Int
    let fixedTargetPct: Double?
    let fixedStopPct: Double?
    let targetATRMultiple: Double?
    let stopATRMultiple: Double?

    let shortFixedTargetPct: Double?
    let shortFixedStopPct: Double?
    let shortTargetATRMultiple: Double?
    let shortStopATRMultiple: Double?

    init(
        id: String,
        name: String,
        kind: LabelCalibrationPolicyKind,
        horizonMinutes: Int,
        fixedTargetPct: Double?,
        fixedStopPct: Double?,
        targetATRMultiple: Double?,
        stopATRMultiple: Double?,
        shortFixedTargetPct: Double? = nil,
        shortFixedStopPct: Double? = nil,
        shortTargetATRMultiple: Double? = nil,
        shortStopATRMultiple: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.horizonMinutes = horizonMinutes
        self.fixedTargetPct = fixedTargetPct
        self.fixedStopPct = fixedStopPct
        self.targetATRMultiple = targetATRMultiple
        self.stopATRMultiple = stopATRMultiple
        self.shortFixedTargetPct = shortFixedTargetPct
        self.shortFixedStopPct = shortFixedStopPct
        self.shortTargetATRMultiple = shortTargetATRMultiple
        self.shortStopATRMultiple = shortStopATRMultiple
    }

    func thresholds(
        atr14Pct: Double
    ) -> (
        longTargetPct: Double,
        longStopPct: Double,
        shortTargetPct: Double,
        shortStopPct: Double
    ) {
        switch kind {
        case .fixed:
            let longTarget =
                fixedTargetPct ?? 0.0075

            let longStop =
                fixedStopPct ?? 0.0035

            return (
                longTarget,
                longStop,
                shortFixedTargetPct
                    ?? longTarget,
                shortFixedStopPct
                    ?? longStop
            )

        case .atrAdaptive:
            let safeATR = max(
                atr14Pct,
                0.0001
            )

            let longTargetMultiple =
                targetATRMultiple ?? 6.0

            let longStopMultiple =
                stopATRMultiple ?? 3.0

            return (
                safeATR
                    * longTargetMultiple,
                safeATR
                    * longStopMultiple,
                safeATR
                    * (
                        shortTargetATRMultiple
                        ?? longTargetMultiple
                    ),
                safeATR
                    * (
                        shortStopATRMultiple
                        ?? longStopMultiple
                    )
            )
        }
    }

    static let candidates: [LabelCalibrationPolicy] = [
        LabelCalibrationPolicy(
            id: "fixed_045_025",
            name: "Fixed 0.45% / 0.25%",
            kind: .fixed,
            horizonMinutes: 90,
            fixedTargetPct: 0.0045,
            fixedStopPct: 0.0025,
            targetATRMultiple: nil,
            stopATRMultiple: nil
        ),
        LabelCalibrationPolicy(
            id: "fixed_055_030",
            name: "Fixed 0.55% / 0.30%",
            kind: .fixed,
            horizonMinutes: 90,
            fixedTargetPct: 0.0055,
            fixedStopPct: 0.0030,
            targetATRMultiple: nil,
            stopATRMultiple: nil
        ),
        LabelCalibrationPolicy(
            id: "fixed_065_035",
            name: "Fixed 0.65% / 0.35%",
            kind: .fixed,
            horizonMinutes: 90,
            fixedTargetPct: 0.0065,
            fixedStopPct: 0.0035,
            targetATRMultiple: nil,
            stopATRMultiple: nil
        ),
        LabelCalibrationPolicy(
            id: "fixed_075_035",
            name: "Fixed 0.75% / 0.35% · baseline",
            kind: .fixed,
            horizonMinutes: 90,
            fixedTargetPct: 0.0075,
            fixedStopPct: 0.0035,
            targetATRMultiple: nil,
            stopATRMultiple: nil
        ),
        LabelCalibrationPolicy(
            id: "fixed_085_040",
            name: "Fixed 0.85% / 0.40%",
            kind: .fixed,
            horizonMinutes: 90,
            fixedTargetPct: 0.0085,
            fixedStopPct: 0.0040,
            targetATRMultiple: nil,
            stopATRMultiple: nil
        ),
        LabelCalibrationPolicy(
            id: "atr_4_2",
            name: "ATR 4.0× / 2.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 4.0,
            stopATRMultiple: 2.0
        ),
        LabelCalibrationPolicy(
            id: "atr_5_25",
            name: "ATR 5.0× / 2.5×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 5.0,
            stopATRMultiple: 2.5
        ),
        LabelCalibrationPolicy(
            id: "atr_6_3",
            name: "ATR 6.0× / 3.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 6.0,
            stopATRMultiple: 3.0
        ),
        LabelCalibrationPolicy(
            id: "atr_7_35",
            name: "ATR 7.0× / 3.5×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 7.0,
            stopATRMultiple: 3.5
        ),
        LabelCalibrationPolicy(
            id: "atr_8_4",
            name: "ATR 8.0× / 4.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 8.0,
            stopATRMultiple: 4.0
        ),
        LabelCalibrationPolicy(
            id: "atr_l8_4_s9_4",
            name: "ATR L 8.0×/4.0× · S 9.0×/4.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 8.0,
            stopATRMultiple: 4.0,
            shortTargetATRMultiple: 9.0,
            shortStopATRMultiple: 4.0
        ),
        LabelCalibrationPolicy(
            id: "atr_l8_4_s10_4",
            name: "ATR L 8.0×/4.0× · S 10.0×/4.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 8.0,
            stopATRMultiple: 4.0,
            shortTargetATRMultiple: 10.0,
            shortStopATRMultiple: 4.0
        ),
        LabelCalibrationPolicy(
            id: "atr_l8_4_s11_45",
            name: "ATR L 8.0×/4.0× · S 11.0×/4.5×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 8.0,
            stopATRMultiple: 4.0,
            shortTargetATRMultiple: 11.0,
            shortStopATRMultiple: 4.5
        ),
        LabelCalibrationPolicy(
            id: "atr_l75_375_s9_4",
            name: "ATR L 7.5×/3.75× · S 9.0×/4.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 7.5,
            stopATRMultiple: 3.75,
            shortTargetATRMultiple: 9.0,
            shortStopATRMultiple: 4.0
        ),
        LabelCalibrationPolicy(
            id: "atr_l75_375_s10_4",
            name: "ATR L 7.5×/3.75× · S 10.0×/4.0×",
            kind: .atrAdaptive,
            horizonMinutes: 90,
            fixedTargetPct: nil,
            fixedStopPct: nil,
            targetATRMultiple: 7.5,
            stopATRMultiple: 3.75,
            shortTargetATRMultiple: 10.0,
            shortStopATRMultiple: 4.0
        )
    ]
}

struct LabelCalibrationCandidateResult: Identifiable, Codable, Sendable {
    let policy: LabelCalibrationPolicy
    let sampleCount: Int

    let longTargetRate: Double
    let shortTargetRate: Double

    let longStopRate: Double
    let shortStopRate: Double

    let longTimeoutRate: Double
    let shortTimeoutRate: Double

    let ambiguousRate: Double

    let longTargetRateStd: Double
    let shortTargetRateStd: Double

    let longPayoffProxy: Double
    let shortPayoffProxy: Double

    let score: Double
    let meetsAcceptanceBand: Bool

    var id: String {
        policy.id
    }
}

struct LabelCalibrationResult: Codable, Sendable {
    let symbol: String
    let calibrationStart: Date
    let calibrationEnd: Date
    let calibrationSessionCount: Int
    let reservedTestSessionCount: Int

    let targetBandLow: Double
    let targetBandHigh: Double
    let maxAmbiguousRate: Double

    let recommendedPolicyID: String?
    let recommendedMeetsAcceptanceBand: Bool

    let candidates: [LabelCalibrationCandidateResult]

    var recommended: LabelCalibrationCandidateResult? {
        guard let recommendedPolicyID else {
            return nil
        }

        return candidates.first {
            $0.policy.id == recommendedPolicyID
        }
    }
}

enum LabelCalibrationEngine {

    static func calibrate(
        asset: AssetConfig,
        bars: [MarketBar],
        folds: [WalkForwardFold],
        candidates: [LabelCalibrationPolicy] =
            LabelCalibrationPolicy.candidates
    ) -> LabelCalibrationResult? {
        guard
            let firstFold = folds.first,
            !candidates.isEmpty
        else {
            return nil
        }

        let calibrationEnd =
            firstFold.validationEnd

        let allSessions = sessionizedBars(
            asset: asset,
            bars: bars
        )

        // The fold boundary is the last eligible research-row timestamp.
        // Keep the full raw bar session so labels near that boundary still
        // have their complete forward horizon without touching a test day.
        let sessions = allSessions.filter { session in
            guard let first =
                    session.bars.first?.timestamp
            else {
                return false
            }

            return first <= calibrationEnd
        }

        guard
            let calibrationStart =
                sessions.first?.bars.first?.timestamp,
            !sessions.isEmpty
        else {
            return nil
        }

        let testSessionKeys = Set(
            folds.flatMap { fold in
                sessionKeys(
                    asset: asset,
                    bars: bars,
                    from: fold.testStart,
                    to: fold.testEnd
                )
            }
        )

        var accumulators: [
            String: CandidateAccumulator
        ] = [:]

        for candidate in candidates {
            accumulators[candidate.id] =
                CandidateAccumulator(
                    policy: candidate
                )
        }

        for session in sessions {
            accumulators = evaluateSession(
                session,
                candidates: candidates,
                accumulators: accumulators
            )
        }

        let targetBandLow = 0.08
        let targetBandHigh = 0.20
        let maxAmbiguousRate = 0.01

        let results = candidates.compactMap {
            candidate -> LabelCalibrationCandidateResult? in

            guard let accumulator =
                    accumulators[candidate.id]
            else {
                return nil
            }

            return accumulator.result(
                targetBandLow: targetBandLow,
                targetBandHigh: targetBandHigh,
                maxAmbiguousRate:
                    maxAmbiguousRate
            )
        }
        .sorted {
            if $0.meetsAcceptanceBand
                != $1.meetsAcceptanceBand {

                return $0.meetsAcceptanceBand
            }

            return $0.score > $1.score
        }

        let recommended = results.first

        return LabelCalibrationResult(
            symbol: asset.symbol,
            calibrationStart:
                calibrationStart,
            calibrationEnd:
                calibrationEnd,
            calibrationSessionCount:
                sessions.count,
            reservedTestSessionCount:
                testSessionKeys.count,
            targetBandLow:
                targetBandLow,
            targetBandHigh:
                targetBandHigh,
            maxAmbiguousRate:
                maxAmbiguousRate,
            recommendedPolicyID:
                recommended?.policy.id,
            recommendedMeetsAcceptanceBand:
                recommended?.meetsAcceptanceBand
                ?? false,
            candidates:
                results
        )
    }

    private struct SessionBars {
        let key: String
        let bars: [MarketBar]
    }

    private struct OutcomeResult {
        let long: ResearchOutcome
        let short: ResearchOutcome
        let futureReturnPct: Double
    }

    private struct SessionCounts {
        var samples = 0
        var longTargets = 0
        var shortTargets = 0
    }

    private struct CandidateAccumulator {
        let policy: LabelCalibrationPolicy

        var samples = 0

        var longTargets = 0
        var shortTargets = 0

        var longStops = 0
        var shortStops = 0

        var longTimeouts = 0
        var shortTimeouts = 0

        var ambiguousRows = 0

        var longPayoffSum = 0.0
        var shortPayoffSum = 0.0

        var sessionLongTargetRates: [Double] = []
        var sessionShortTargetRates: [Double] = []

        mutating func add(
            outcome: OutcomeResult,
            longTargetPct: Double,
            longStopPct: Double,
            shortTargetPct: Double,
            shortStopPct: Double
        ) {
            samples += 1

            switch outcome.long {
            case .target:
                longTargets += 1
                longPayoffSum += longTargetPct

            case .stop:
                longStops += 1
                longPayoffSum -= longStopPct

            case .timeout:
                longTimeouts += 1
                longPayoffSum +=
                    outcome.futureReturnPct

            case .ambiguous:
                break
            }

            switch outcome.short {
            case .target:
                shortTargets += 1
                shortPayoffSum += shortTargetPct

            case .stop:
                shortStops += 1
                shortPayoffSum -= shortStopPct

            case .timeout:
                shortTimeouts += 1
                shortPayoffSum -=
                    outcome.futureReturnPct

            case .ambiguous:
                break
            }

            if outcome.long == .ambiguous
                || outcome.short == .ambiguous {

                ambiguousRows += 1
            }
        }

        mutating func finishSession(
            counts: SessionCounts
        ) {
            guard counts.samples > 0 else {
                return
            }

            let denominator = Double(
                counts.samples
            )

            sessionLongTargetRates.append(
                Double(counts.longTargets)
                / denominator
            )

            sessionShortTargetRates.append(
                Double(counts.shortTargets)
                / denominator
            )
        }

        func result(
            targetBandLow: Double,
            targetBandHigh: Double,
            maxAmbiguousRate: Double
        ) -> LabelCalibrationCandidateResult {
            let denominator = Double(
                max(samples, 1)
            )

            let longTargetRate =
                Double(longTargets) / denominator

            let shortTargetRate =
                Double(shortTargets) / denominator

            let longStopRate =
                Double(longStops) / denominator

            let shortStopRate =
                Double(shortStops) / denominator

            let longTimeoutRate =
                Double(longTimeouts) / denominator

            let shortTimeoutRate =
                Double(shortTimeouts) / denominator

            // A row may be ambiguous for both LONG and SHORT.
            // Cap the row-level proxy at 100%.
            let ambiguousRate = min(
                Double(ambiguousRows)
                / denominator,
                1
            )

            let longStd =
                LabelCalibrationEngine.standardDeviation(
                    sessionLongTargetRates
                )

            let shortStd =
                LabelCalibrationEngine.standardDeviation(
                    sessionShortTargetRates
                )

            let longBandScore =
                LabelCalibrationEngine.bandFit(
                    longTargetRate,
                    low: targetBandLow,
                    high: targetBandHigh
                )

            let shortBandScore =
                LabelCalibrationEngine.bandFit(
                    shortTargetRate,
                    low: targetBandLow,
                    high: targetBandHigh
                )

            let balanceScore =
                1 - min(
                    abs(
                        longTargetRate
                        - shortTargetRate
                    ) / 0.12,
                    1
                )

            let stabilityScore =
                1 - min(
                    (longStd + shortStd)
                    / 0.20,
                    1
                )

            let ambiguityScore =
                1 - min(
                    ambiguousRate
                    / max(
                        maxAmbiguousRate * 2,
                        0.0001
                    ),
                    1
                )

            let score =
                30 * longBandScore
                + 30 * shortBandScore
                + 15 * balanceScore
                + 15 * stabilityScore
                + 10 * ambiguityScore

            let accepted =
                longTargetRate >= targetBandLow
                && longTargetRate <= targetBandHigh
                && shortTargetRate >= targetBandLow
                && shortTargetRate <= targetBandHigh
                && ambiguousRate <= maxAmbiguousRate

            return LabelCalibrationCandidateResult(
                policy: policy,
                sampleCount: samples,
                longTargetRate:
                    longTargetRate,
                shortTargetRate:
                    shortTargetRate,
                longStopRate:
                    longStopRate,
                shortStopRate:
                    shortStopRate,
                longTimeoutRate:
                    longTimeoutRate,
                shortTimeoutRate:
                    shortTimeoutRate,
                ambiguousRate:
                    ambiguousRate,
                longTargetRateStd:
                    longStd,
                shortTargetRateStd:
                    shortStd,
                longPayoffProxy:
                    longPayoffSum / denominator,
                shortPayoffProxy:
                    shortPayoffSum / denominator,
                score:
                    score,
                meetsAcceptanceBand:
                    accepted
            )
        }
    }

    private static func evaluateSession(
        _ session: SessionBars,
        candidates: [LabelCalibrationPolicy],
        accumulators: [
            String: CandidateAccumulator
        ]
    ) -> [
        String: CandidateAccumulator
    ] {
        let bars = session.bars
        let minimumHistory = 60

        guard bars.count > minimumHistory else {
            return accumulators
        }

        var updatedAccumulators =
            accumulators

        var sessionCounts: [
            String: SessionCounts
        ] = [:]

        for candidate in candidates {
            sessionCounts[candidate.id] =
                SessionCounts()
        }

        for candidate in candidates {
            let horizon =
                candidate.horizonMinutes

            let lastEligibleIndex =
                bars.count - horizon - 1

            guard lastEligibleIndex
                    >= minimumHistory
            else {
                continue
            }

            for index in
                minimumHistory...lastEligibleIndex {

                let atr14Pct =
                    averageTrueRangePct(
                        bars: bars,
                        endIndex: index,
                        period: 14
                    )

                let thresholds =
                    candidate.thresholds(
                        atr14Pct: atr14Pct
                    )

                let outcome =
                    evaluateOutcome(
                        bars: bars,
                        entryIndex: index,
                        horizonMinutes:
                            horizon,
                        longTargetPct:
                            thresholds.longTargetPct,
                        longStopPct:
                            thresholds.longStopPct,
                        shortTargetPct:
                            thresholds.shortTargetPct,
                        shortStopPct:
                            thresholds.shortStopPct
                    )

                if var accumulator =
                    updatedAccumulators[
                        candidate.id
                    ] {

                    accumulator.add(
                        outcome: outcome,
                        longTargetPct:
                            thresholds.longTargetPct,
                        longStopPct:
                            thresholds.longStopPct,
                        shortTargetPct:
                            thresholds.shortTargetPct,
                        shortStopPct:
                            thresholds.shortStopPct
                    )

                    updatedAccumulators[
                        candidate.id
                    ] = accumulator
                }

                if var counts =
                    sessionCounts[
                        candidate.id
                    ] {

                    counts.samples += 1

                    if outcome.long == .target {
                        counts.longTargets += 1
                    }

                    if outcome.short == .target {
                        counts.shortTargets += 1
                    }

                    sessionCounts[
                        candidate.id
                    ] = counts
                }
            }
        }

        for candidate in candidates {
            guard
                var accumulator =
                    updatedAccumulators[
                        candidate.id
                    ],
                let counts =
                    sessionCounts[
                        candidate.id
                    ]
            else {
                continue
            }

            accumulator.finishSession(
                counts: counts
            )

            updatedAccumulators[
                candidate.id
            ] = accumulator
        }

        return updatedAccumulators
    }

    private static func evaluateOutcome(
        bars: [MarketBar],
        entryIndex: Int,
        horizonMinutes: Int,
        longTargetPct: Double,
        longStopPct: Double,
        shortTargetPct: Double,
        shortStopPct: Double
    ) -> OutcomeResult {
        let entry = bars[entryIndex].close

        let endIndex = min(
            entryIndex + horizonMinutes,
            bars.count - 1
        )

        let longTarget =
            entry * (1 + longTargetPct)

        let longStop =
            entry * (1 - longStopPct)

        let shortTarget =
            entry * (1 - shortTargetPct)

        let shortStop =
            entry * (1 + shortStopPct)

        var longOutcome:
            ResearchOutcome?

        var shortOutcome:
            ResearchOutcome?

        if entryIndex + 1 <= endIndex {
            for index in
                (entryIndex + 1)...endIndex {

                let bar = bars[index]

                if longOutcome == nil {
                    let targetHit =
                        bar.high >= longTarget

                    let stopHit =
                        bar.low <= longStop

                    if targetHit && stopHit {
                        longOutcome =
                            .ambiguous

                    } else if targetHit {
                        longOutcome =
                            .target

                    } else if stopHit {
                        longOutcome =
                            .stop
                    }
                }

                if shortOutcome == nil {
                    let targetHit =
                        bar.low <= shortTarget

                    let stopHit =
                        bar.high >= shortStop

                    if targetHit && stopHit {
                        shortOutcome =
                            .ambiguous

                    } else if targetHit {
                        shortOutcome =
                            .target

                    } else if stopHit {
                        shortOutcome =
                            .stop
                    }
                }
            }
        }

        let endClose =
            bars[endIndex].close

        let futureReturn =
            entry == 0
            ? 0
            : endClose / entry - 1

        return OutcomeResult(
            long:
                longOutcome ?? .timeout,
            short:
                shortOutcome ?? .timeout,
            futureReturnPct:
                futureReturn
        )
    }

    private static func sessionizedBars(
        asset: AssetConfig,
        bars: [MarketBar]
    ) -> [SessionBars] {
        let timezone =
            TimeZone(identifier: asset.timezone)
            ?? TimeZone(secondsFromGMT: 0)!

        var calendar = Calendar(
            identifier: .gregorian
        )
        calendar.timeZone = timezone

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"

        var grouped: [
            String: [MarketBar]
        ] = [:]

        for bar in bars {
            let components =
                calendar.dateComponents(
                    [.weekday, .hour, .minute],
                    from: bar.timestamp
                )

            let weekday =
                components.weekday ?? 1

            let hour =
                components.hour ?? 0

            let minute =
                components.minute ?? 0

            if asset.assetClass != .crypto {
                if weekday == 1
                    || weekday == 7 {

                    continue
                }

                let minuteOfDay =
                    hour * 60 + minute

                let open =
                    9 * 60 + 30

                let close =
                    16 * 60

                guard
                    minuteOfDay >= open,
                    minuteOfDay < close
                else {
                    continue
                }
            }

            let key = formatter.string(
                from: bar.timestamp
            )

            grouped[key, default: []].append(
                bar
            )
        }

        return grouped
            .map { key, values in
                SessionBars(
                    key: key,
                    bars: values.sorted {
                        $0.timestamp
                            < $1.timestamp
                    }
                )
            }
            .sorted {
                guard
                    let lhs =
                        $0.bars.first?.timestamp,
                    let rhs =
                        $1.bars.first?.timestamp
                else {
                    return $0.key < $1.key
                }

                return lhs < rhs
            }
    }

    private static func sessionKeys(
        asset: AssetConfig,
        bars: [MarketBar],
        from start: Date,
        to end: Date
    ) -> [String] {
        sessionizedBars(
            asset: asset,
            bars: bars.filter {
                $0.timestamp >= start
                && $0.timestamp <= end
            }
        )
        .map {
            $0.key
        }
    }

    private static func averageTrueRangePct(
        bars: [MarketBar],
        endIndex: Int,
        period: Int
    ) -> Double {
        let start = max(
            1,
            endIndex - period + 1
        )

        let ranges = (
            start...endIndex
        ).map { index -> Double in
            let bar = bars[index]
            let previousClose =
                bars[index - 1].close

            return max(
                bar.high - bar.low,
                abs(
                    bar.high
                    - previousClose
                ),
                abs(
                    bar.low
                    - previousClose
                )
            )
        }

        let averageRange =
            ranges.reduce(0, +)
            / Double(
                max(ranges.count, 1)
            )

        let close =
            bars[endIndex].close

        guard close != 0 else {
            return 0
        }

        return averageRange / close
    }

    private static func bandFit(
        _ value: Double,
        low: Double,
        high: Double
    ) -> Double {
        if value >= low,
           value <= high {

            return 1
        }

        if value < low {
            return max(
                0,
                1 - (low - value)
                    / max(low, 0.0001)
            )
        }

        return max(
            0,
            1 - (value - high)
                / max(high, 0.0001)
        )
    }

    private static func standardDeviation(
        _ values: [Double]
    ) -> Double {
        guard values.count > 1 else {
            return 0
        }

        let mean =
            values.reduce(0, +)
            / Double(values.count)

        let variance =
            values.reduce(0) {
                partial, value in

                partial
                + pow(
                    value - mean,
                    2
                )
            }
            / Double(values.count)

        return sqrt(
            max(variance, 0)
        )
    }
}
