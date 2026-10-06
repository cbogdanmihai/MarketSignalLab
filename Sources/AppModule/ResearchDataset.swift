import Foundation

enum ResearchOutcome: String, Codable, Sendable {
    case target
    case stop
    case timeout
    case ambiguous
}

struct ResearchLabelConfig: Codable, Equatable, Sendable {
    let targetPct: Double
    let stopPct: Double
    let horizonMinutes: Int

    static let defaultIntraday = ResearchLabelConfig(
        targetPct: 0.0075,
        stopPct: 0.0035,
        horizonMinutes: 90
    )
}

struct ResearchRow: Identifiable, Codable, Sendable {
    let symbol: String
    let timestamp: Date
    let sessionKey: String
    let minuteOfSession: Int
    let sessionProgress: Double

    let close: Double

    let return1: Double
    let return5: Double
    let return15: Double
    let return30: Double
    let return60: Double

    let rangePct: Double
    let atr14Pct: Double
    let realizedVol20: Double
    let volumeZ20: Double?

    let distanceToSMA20: Double
    let distanceToSMA50: Double
    let distanceToSessionHigh: Double
    let distanceToSessionLow: Double
    let distanceToSessionVWAP: Double?

    let futureReturnPct: Double
    let mfePct: Double
    let maePct: Double

    let longOutcome: ResearchOutcome
    let shortOutcome: ResearchOutcome

    var id: String {
        "\(symbol)|\(timestamp.timeIntervalSince1970)"
    }
}

struct WalkForwardFold: Identifiable, Codable, Sendable {
    let fold: Int

    let trainStart: Date
    let trainEnd: Date

    let validationStart: Date
    let validationEnd: Date

    let testStart: Date
    let testEnd: Date

    let trainCount: Int
    let validationCount: Int
    let testCount: Int

    var id: Int {
        fold
    }
}

struct ResearchDatasetSummary: Codable, Sendable {
    let symbol: String
    let rawBarCount: Int
    let eligibleBarCount: Int
    let rowCount: Int
    let featureCount: Int
    let sessionCount: Int
    let earliestRow: Date?
    let latestRow: Date?
    let longTargetRate: Double
    let shortTargetRate: Double
    let longTimeoutRate: Double
    let shortTimeoutRate: Double
    let ambiguousRate: Double
}

struct ResearchDatasetBuildResult: Sendable {
    let rows: [ResearchRow]
    let folds: [WalkForwardFold]
    let summary: ResearchDatasetSummary
}

enum ResearchDatasetBuilder {

    static func build(
        asset: AssetConfig,
        bars: [MarketBar],
        labelConfig: ResearchLabelConfig = .defaultIntraday
    ) -> ResearchDatasetBuildResult {
        let ordered = bars.sorted {
            $0.timestamp < $1.timestamp
        }

        let sessions = sessionizedBars(
            asset: asset,
            bars: ordered
        )

        var rows: [ResearchRow] = []
        rows.reserveCapacity(ordered.count)

        var eligibleBarCount = 0

        for session in sessions {
            eligibleBarCount += session.bars.count

            rows.append(
                contentsOf: buildSessionRows(
                    asset: asset,
                    session: session,
                    labelConfig: labelConfig
                )
            )
        }

        let folds = makeWalkForwardFolds(
            rows: rows,
            horizonMinutes: labelConfig.horizonMinutes
        )

        let rowCount = rows.count

        let longTargets = rows.filter {
            $0.longOutcome == .target
        }.count

        let shortTargets = rows.filter {
            $0.shortOutcome == .target
        }.count

        let longTimeouts = rows.filter {
            $0.longOutcome == .timeout
        }.count

        let shortTimeouts = rows.filter {
            $0.shortOutcome == .timeout
        }.count

        let ambiguous = rows.filter {
            $0.longOutcome == .ambiguous
            || $0.shortOutcome == .ambiguous
        }.count

        let denominator = Double(
            max(rowCount, 1)
        )

        let summary = ResearchDatasetSummary(
            symbol: asset.symbol,
            rawBarCount: ordered.count,
            eligibleBarCount: eligibleBarCount,
            rowCount: rowCount,
            featureCount: 16,
            sessionCount: sessions.count,
            earliestRow: rows.first?.timestamp,
            latestRow: rows.last?.timestamp,
            longTargetRate: Double(longTargets) / denominator,
            shortTargetRate: Double(shortTargets) / denominator,
            longTimeoutRate: Double(longTimeouts) / denominator,
            shortTimeoutRate: Double(shortTimeouts) / denominator,
            ambiguousRate: Double(ambiguous) / denominator
        )

        return ResearchDatasetBuildResult(
            rows: rows,
            folds: folds,
            summary: summary
        )
    }

    private struct SessionBars: Sendable {
        let key: String
        let bars: [MarketBar]
        let minuteOfSession: [Int]
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

        var grouped: [String: [(MarketBar, Int)]] = [:]

        for bar in bars {
            let components = calendar.dateComponents(
                [.weekday, .hour, .minute],
                from: bar.timestamp
            )

            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let weekday = components.weekday ?? 1

            if asset.assetClass != .crypto {
                if weekday == 1 || weekday == 7 {
                    continue
                }

                let minuteOfDay =
                    hour * 60 + minute

                let regularOpen = 9 * 60 + 30
                let regularClose = 16 * 60

                guard minuteOfDay >= regularOpen,
                      minuteOfDay < regularClose else {
                    continue
                }

                let sessionMinute =
                    minuteOfDay - regularOpen

                let key = formatter.string(
                    from: bar.timestamp
                )

                grouped[key, default: []].append(
                    (bar, sessionMinute)
                )

            } else {
                let minuteOfDay =
                    hour * 60 + minute

                let key = formatter.string(
                    from: bar.timestamp
                )

                grouped[key, default: []].append(
                    (bar, minuteOfDay)
                )
            }
        }

        return grouped
            .map { key, values in
                let orderedValues = values.sorted {
                    $0.0.timestamp < $1.0.timestamp
                }

                return SessionBars(
                    key: key,
                    bars: orderedValues.map {
                        $0.0
                    },
                    minuteOfSession: orderedValues.map {
                        $0.1
                    }
                )
            }
            .sorted {
                guard
                    let lhs = $0.bars.first?.timestamp,
                    let rhs = $1.bars.first?.timestamp
                else {
                    return $0.key < $1.key
                }

                return lhs < rhs
            }
    }

    private static func buildSessionRows(
        asset: AssetConfig,
        session: SessionBars,
        labelConfig: ResearchLabelConfig
    ) -> [ResearchRow] {
        let bars = session.bars

        let minimumHistory = 60

        guard bars.count >
                minimumHistory + labelConfig.horizonMinutes else {
            return []
        }

        var sessionHigh = -Double.infinity
        var sessionLow = Double.infinity

        var cumulativePV = 0.0
        var cumulativeVolume = 0.0

        var sessionVWAP: [Double?] = Array(
            repeating: nil,
            count: bars.count
        )

        var runningHigh: [Double] = []
        var runningLow: [Double] = []

        runningHigh.reserveCapacity(
            bars.count
        )
        runningLow.reserveCapacity(
            bars.count
        )

        for (index, bar) in bars.enumerated() {
            sessionHigh = max(
                sessionHigh,
                bar.high
            )

            sessionLow = min(
                sessionLow,
                bar.low
            )

            runningHigh.append(
                sessionHigh
            )

            runningLow.append(
                sessionLow
            )

            if let volume = bar.volume,
               volume > 0 {

                let typical =
                    (bar.high + bar.low + bar.close)
                    / 3.0

                cumulativePV += typical * volume
                cumulativeVolume += volume

                if cumulativeVolume > 0 {
                    sessionVWAP[index] =
                        cumulativePV / cumulativeVolume
                }
            }
        }

        var result: [ResearchRow] = []

        let lastEligibleIndex =
            bars.count - labelConfig.horizonMinutes - 1

        guard lastEligibleIndex >= minimumHistory else {
            return []
        }

        for i in minimumHistory...lastEligibleIndex {
            let current = bars[i]

            let ret1 = returnPct(
                current.close,
                bars[i - 1].close
            )

            let ret5 = returnPct(
                current.close,
                bars[i - 5].close
            )

            let ret15 = returnPct(
                current.close,
                bars[i - 15].close
            )

            let ret30 = returnPct(
                current.close,
                bars[i - 30].close
            )

            let ret60 = returnPct(
                current.close,
                bars[i - 60].close
            )

            let atr14 = averageTrueRangePct(
                bars: bars,
                endIndex: i,
                period: 14
            )

            let realizedVol20 =
                rollingStdDev(
                    values: (i - 19...i).map { index in
                        guard index > 0 else {
                            return 0
                        }

                        return returnPct(
                            bars[index].close,
                            bars[index - 1].close
                        )
                    }
                )

            let volumeZ20 = rollingVolumeZScore(
                bars: bars,
                endIndex: i,
                period: 20
            )

            let sma20 = average(
                values: (i - 19...i).map {
                    bars[$0].close
                }
            )

            let sma50 = average(
                values: (i - 49...i).map {
                    bars[$0].close
                }
            )

            let labels = evaluateLabels(
                bars: bars,
                entryIndex: i,
                config: labelConfig
            )

            let totalSessionMinutes =
                asset.assetClass == .crypto
                ? 1440.0
                : 390.0

            let minute = session.minuteOfSession[i]

            let progress = min(
                max(
                    Double(minute)
                    / max(totalSessionMinutes - 1, 1),
                    0
                ),
                1
            )

            let rangePct =
                current.close == 0
                ? 0
                : (current.high - current.low)
                    / current.close

            let vwapDistance: Double?

            if let vwap = sessionVWAP[i],
               vwap != 0 {

                vwapDistance =
                    current.close / vwap - 1

            } else {
                vwapDistance = nil
            }

            result.append(
                ResearchRow(
                    symbol: asset.symbol,
                    timestamp: current.timestamp,
                    sessionKey: session.key,
                    minuteOfSession: minute,
                    sessionProgress: progress,
                    close: current.close,
                    return1: ret1,
                    return5: ret5,
                    return15: ret15,
                    return30: ret30,
                    return60: ret60,
                    rangePct: rangePct,
                    atr14Pct: atr14,
                    realizedVol20: realizedVol20,
                    volumeZ20: volumeZ20,
                    distanceToSMA20:
                        current.close / sma20 - 1,
                    distanceToSMA50:
                        current.close / sma50 - 1,
                    distanceToSessionHigh:
                        current.close / runningHigh[i] - 1,
                    distanceToSessionLow:
                        current.close / runningLow[i] - 1,
                    distanceToSessionVWAP:
                        vwapDistance,
                    futureReturnPct:
                        labels.futureReturnPct,
                    mfePct: labels.mfePct,
                    maePct: labels.maePct,
                    longOutcome:
                        labels.longOutcome,
                    shortOutcome:
                        labels.shortOutcome
                )
            )
        }

        return result
    }

    private struct LabelResult {
        let futureReturnPct: Double
        let mfePct: Double
        let maePct: Double
        let longOutcome: ResearchOutcome
        let shortOutcome: ResearchOutcome
    }

    private static func evaluateLabels(
        bars: [MarketBar],
        entryIndex: Int,
        config: ResearchLabelConfig
    ) -> LabelResult {
        let entry = bars[entryIndex].close

        let endIndex = min(
            entryIndex + config.horizonMinutes,
            bars.count - 1
        )

        let longTarget =
            entry * (1 + config.targetPct)

        let longStop =
            entry * (1 - config.stopPct)

        let shortTarget =
            entry * (1 - config.targetPct)

        let shortStop =
            entry * (1 + config.stopPct)

        var longOutcome: ResearchOutcome?
        var shortOutcome: ResearchOutcome?

        var maxHigh = entry
        var minLow = entry

        if entryIndex + 1 <= endIndex {
            for j in (entryIndex + 1)...endIndex {
                let bar = bars[j]

                maxHigh = max(
                    maxHigh,
                    bar.high
                )

                minLow = min(
                    minLow,
                    bar.low
                )

                if longOutcome == nil {
                    let hitTarget =
                        bar.high >= longTarget

                    let hitStop =
                        bar.low <= longStop

                    if hitTarget && hitStop {
                        longOutcome = .ambiguous
                    } else if hitTarget {
                        longOutcome = .target
                    } else if hitStop {
                        longOutcome = .stop
                    }
                }

                if shortOutcome == nil {
                    let hitTarget =
                        bar.low <= shortTarget

                    let hitStop =
                        bar.high >= shortStop

                    if hitTarget && hitStop {
                        shortOutcome = .ambiguous
                    } else if hitTarget {
                        shortOutcome = .target
                    } else if hitStop {
                        shortOutcome = .stop
                    }
                }

                if longOutcome != nil,
                   shortOutcome != nil {
                    break
                }
            }
        }

        let endClose = bars[endIndex].close

        let futureReturn =
            returnPct(
                endClose,
                entry
            )

        let mfe =
            entry == 0
            ? 0
            : maxHigh / entry - 1

        let mae =
            entry == 0
            ? 0
            : minLow / entry - 1

        return LabelResult(
            futureReturnPct: futureReturn,
            mfePct: mfe,
            maePct: mae,
            longOutcome:
                longOutcome ?? .timeout,
            shortOutcome:
                shortOutcome ?? .timeout
        )
    }

    private static func makeWalkForwardFolds(
        rows: [ResearchRow],
        horizonMinutes: Int
    ) -> [WalkForwardFold] {
        guard rows.count >= 600 else {
            return []
        }

        let ordered = rows.sorted {
            $0.timestamp < $1.timestamp
        }

        let blockSize =
            max(1, ordered.count / 6)

        var folds: [WalkForwardFold] = []

        for fold in 1...3 {
            let trainBoundaryIndex = min(
                blockSize * (fold + 1) - 1,
                ordered.count - 1
            )

            let validationBoundaryIndex = min(
                trainBoundaryIndex + blockSize,
                ordered.count - 1
            )

            let testBoundaryIndex = min(
                validationBoundaryIndex + blockSize,
                ordered.count - 1
            )

            guard trainBoundaryIndex > 0,
                  validationBoundaryIndex > trainBoundaryIndex,
                  testBoundaryIndex > validationBoundaryIndex
            else {
                continue
            }

            let trainBoundary =
                ordered[trainBoundaryIndex].timestamp

            let validationBoundary =
                ordered[validationBoundaryIndex].timestamp

            let testBoundary =
                ordered[testBoundaryIndex].timestamp

            let purgeSeconds =
                TimeInterval(
                    horizonMinutes * 60
                )

            let trainSafeEnd =
                trainBoundary.addingTimeInterval(
                    -purgeSeconds
                )

            let validationSafeEnd =
                validationBoundary.addingTimeInterval(
                    -purgeSeconds
                )

            let trainRows = ordered.filter {
                $0.timestamp <= trainSafeEnd
            }

            let validationRows = ordered.filter {
                $0.timestamp > trainBoundary
                && $0.timestamp <= validationSafeEnd
            }

            let testRows = ordered.filter {
                $0.timestamp > validationBoundary
                && $0.timestamp <= testBoundary
            }

            guard
                let trainStart =
                    trainRows.first?.timestamp,
                let trainEnd =
                    trainRows.last?.timestamp,
                let validationStart =
                    validationRows.first?.timestamp,
                let validationEnd =
                    validationRows.last?.timestamp,
                let testStart =
                    testRows.first?.timestamp,
                let testEnd =
                    testRows.last?.timestamp,
                !validationRows.isEmpty,
                !testRows.isEmpty
            else {
                continue
            }

            folds.append(
                WalkForwardFold(
                    fold: fold,
                    trainStart: trainStart,
                    trainEnd: trainEnd,
                    validationStart:
                        validationStart,
                    validationEnd:
                        validationEnd,
                    testStart: testStart,
                    testEnd: testEnd,
                    trainCount:
                        trainRows.count,
                    validationCount:
                        validationRows.count,
                    testCount:
                        testRows.count
                )
            )
        }

        return folds
    }

    private static func returnPct(
        _ current: Double,
        _ previous: Double
    ) -> Double {
        guard previous != 0 else {
            return 0
        }

        return current / previous - 1
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

        let ranges = (start...endIndex).map {
            index -> Double in

            let bar = bars[index]
            let previousClose =
                bars[index - 1].close

            return max(
                bar.high - bar.low,
                abs(bar.high - previousClose),
                abs(bar.low - previousClose)
            )
        }

        let atr = average(
            values: ranges
        )

        let close = bars[endIndex].close

        guard close != 0 else {
            return 0
        }

        return atr / close
    }

    private static func rollingVolumeZScore(
        bars: [MarketBar],
        endIndex: Int,
        period: Int
    ) -> Double? {
        let start =
            endIndex - period + 1

        guard start >= 0 else {
            return nil
        }

        let volumes =
            (start...endIndex).compactMap {
                bars[$0].volume
            }

        guard volumes.count == period,
              let current =
                bars[endIndex].volume
        else {
            return nil
        }

        let mean = average(
            values: volumes
        )

        let variance = average(
            values: volumes.map {
                pow($0 - mean, 2)
            }
        )

        let std = sqrt(
            max(variance, 0)
        )

        guard std > 0 else {
            return 0
        }

        return (current - mean) / std
    }

    private static func rollingStdDev(
        values: [Double]
    ) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        let mean = average(
            values: values
        )

        let variance = average(
            values: values.map {
                pow($0 - mean, 2)
            }
        )

        return sqrt(
            max(variance, 0)
        )
    }

    private static func average(
        values: [Double]
    ) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(
            0,
            +
        ) / Double(values.count)
    }
}
