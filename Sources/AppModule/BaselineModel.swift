import Foundation

enum BaselineDirection:
    String,
    Codable,
    Sendable {

    case long = "LONG"
    case short = "SHORT"
}

enum BaselineFeatureVariant:
    String,
    Codable,
    Sendable,
    CaseIterable {

    case core16 = "core16"
    case selfRegime22 = "self_regime22"
    case marketContext28 = "market_context28"

    var title: String {
        switch self {
        case .core16:
            return "Core 16"

        case .selfRegime22:
            return "Self Regime 22"

        case .marketContext28:
            return "Market Context 28"
        }
    }

    var subtitle: String {
        switch self {
        case .core16:
            return "Original causal intraday features"

        case .selfRegime22:
            return "Core + six self-regime features"

        case .marketContext28:
            return "Core + SPY / IWM / VIXY context"
        }
    }
}

struct BaselineClassificationMetrics:
    Codable,
    Sendable {

    let samples: Int
    let prevalence: Double
    let meanProbability: Double
    let threshold: Double
    let brierScore: Double
    let expectedCalibrationError: Double
    let precision: Double
    let recall: Double
    let f1: Double
    let accuracy: Double
}

struct BaselineFoldResult:
    Identifiable,
    Codable,
    Sendable {

    let fold: Int
    let direction: BaselineDirection

    let trainSamples: Int
    let validationSamples: Int
    let testSamples: Int

    let trainPrevalence: Double
    let validationPrevalence: Double
    let testPrevalence: Double
    let validationThreshold: Double
    let selectedL2: Double

    let trainPriorTestBrier: Double
    let validationPriorTestBrier: Double

    let rawLogisticTest:
        BaselineClassificationMetrics

    let calibratedTest:
        BaselineClassificationMetrics

    var id: String {
        "\(fold)|\(direction.rawValue)"
    }

    var noSkillTestBrier: Double {
        validationPriorTestBrier
    }

    var logisticTest:
        BaselineClassificationMetrics {

        calibratedTest
    }

    var rawBrierSkill: Double {
        skill(
            modelBrier:
                rawLogisticTest.brierScore
        )
    }

    var brierSkill: Double {
        skill(
            modelBrier:
                calibratedTest.brierScore
        )
    }

    var beatsNoSkill: Bool {
        calibratedTest.brierScore
            < validationPriorTestBrier
    }

    private func skill(
        modelBrier: Double
    ) -> Double {
        guard
            validationPriorTestBrier
                > 0
        else {
            return 0
        }

        return 1
            - (
                modelBrier
                / validationPriorTestBrier
            )
    }
}

struct BaselineRunResult:
    Codable,
    Sendable,
    Identifiable {

    let variant: BaselineFeatureVariant
    let symbol: String
    let generatedAt: Date
    let lockedPolicyID: String
    let lockedPolicyName: String
    let featureNames: [String]
    let contextCoverage: Double
    let folds: [BaselineFoldResult]

    var id: String {
        variant.rawValue
    }

    var longFolds:
        [BaselineFoldResult] {

        folds.filter {
            $0.direction == .long
        }
    }

    var shortFolds:
        [BaselineFoldResult] {

        folds.filter {
            $0.direction == .short
        }
    }

    var meanLongSkill: Double {
        mean(
            longFolds.map {
                $0.brierSkill
            }
        )
    }

    var meanShortSkill: Double {
        mean(
            shortFolds.map {
                $0.brierSkill
            }
        )
    }

    var meanRawLongSkill: Double {
        mean(
            longFolds.map {
                $0.rawBrierSkill
            }
        )
    }

    var meanRawShortSkill: Double {
        mean(
            shortFolds.map {
                $0.rawBrierSkill
            }
        )
    }

    var combinedDevelopmentScore: Double {
        min(
            meanLongSkill,
            meanShortSkill
        )
    }

    var passesInitialGate: Bool {
        guard
            longFolds.count >= 3,
            shortFolds.count >= 3
        else {
            return false
        }

        return meanLongSkill > 0
            && meanShortSkill > 0
    }

    private func mean(
        _ values: [Double]
    ) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(
            0,
            +
        )
        / Double(values.count)
    }
}

struct BaselineDirectionGate:
    Codable,
    Sendable {

    let direction: BaselineDirection
    let variant: BaselineFeatureVariant?
    let meanSkill: Double
    let positiveFoldCount: Int
    let foldCount: Int
    let worstFoldSkill: Double
    let enabled: Bool
    let reason: String

    var modeLabel: String {
        enabled
        ? direction.rawValue
        : "NO_TRADE"
    }
}

struct BaselineDirectionalGateSummary:
    Codable,
    Sendable {

    let long: BaselineDirectionGate
    let short: BaselineDirectionGate

    var mode: String {
        switch (
            long.enabled,
            short.enabled
        ) {
        case (true, true):
            return "BIDIRECTIONAL"

        case (true, false):
            return "LONG_ONLY"

        case (false, true):
            return "SHORT_ONLY"

        case (false, false):
            return "NO_TRADE"
        }
    }
}

struct BaselineExperimentResult:
    Codable,
    Sendable {

    let symbol: String
    let generatedAt: Date
    let candidates: [BaselineRunResult]
    let recommendedVariant:
        BaselineFeatureVariant?

    var recommended:
        BaselineRunResult? {

        guard let recommendedVariant else {
            return nil
        }

        return candidates.first {
            $0.variant
                == recommendedVariant
        }
    }

    var bestLong:
        BaselineRunResult? {

        candidates.max {
            $0.meanLongSkill
                < $1.meanLongSkill
        }
    }

    var bestShort:
        BaselineRunResult? {

        candidates.max {
            $0.meanShortSkill
                < $1.meanShortSkill
        }
    }

    var directionalGate:
        BaselineDirectionalGateSummary {

        Self.directionalGate(
            for: candidates
        )
    }

    static func directionalGate(
        for candidates:
            [BaselineRunResult]
    ) -> BaselineDirectionalGateSummary {
        let bestLong =
            candidates.max {
                $0.meanLongSkill
                    < $1.meanLongSkill
            }

        let bestShort =
            candidates.max {
                $0.meanShortSkill
                    < $1.meanShortSkill
            }

        return BaselineDirectionalGateSummary(
            long:
                Self.makeGate(
                    direction: .long,
                    candidate:
                        bestLong
                ),
            short:
                Self.makeGate(
                    direction: .short,
                    candidate:
                        bestShort
                )
        )
    }

    private static func makeGate(
        direction:
            BaselineDirection,
        candidate:
            BaselineRunResult?
    ) -> BaselineDirectionGate {
        guard let candidate else {
            return BaselineDirectionGate(
                direction: direction,
                variant: nil,
                meanSkill: 0,
                positiveFoldCount: 0,
                foldCount: 0,
                worstFoldSkill: 0,
                enabled: false,
                reason:
                    "No eligible development model."
            )
        }

        let folds =
            direction == .long
            ? candidate.longFolds
            : candidate.shortFolds

        let skills =
            folds.map {
                $0.brierSkill
            }

        let meanSkill =
            direction == .long
            ? candidate.meanLongSkill
            : candidate.meanShortSkill

        let positiveFoldCount =
            skills.filter {
                $0 > 0
            }
            .count

        let worstFoldSkill =
            skills.min()
            ?? 0

        let enoughFolds =
            folds.count >= 3

        let stableEnough =
            positiveFoldCount >= 2

        let enabled =
            enoughFolds
            && meanSkill > 0
            && stableEnough

        let reason: String

        if !enoughFolds {
            reason =
                "Fewer than three development OOS folds."

        } else if meanSkill <= 0 {
            reason =
                "Mean development Brier skill is not positive."

        } else if !stableEnough {
            reason =
                "Positive skill appears in fewer than two of three folds."

        } else {
            reason =
                "Positive mean Brier skill with at least two positive development folds."
        }

        return BaselineDirectionGate(
            direction: direction,
            variant:
                candidate.variant,
            meanSkill:
                meanSkill,
            positiveFoldCount:
                positiveFoldCount,
            foldCount:
                folds.count,
            worstFoldSkill:
                worstFoldSkill,
            enabled:
                enabled,
            reason:
                reason
        )
    }
}

struct SealedHoldoutDirectionResult:
    Identifiable,
    Codable,
    Sendable {

    let direction: BaselineDirection
    let variant: BaselineFeatureVariant
    let trainSessionCount: Int
    let calibrationSessionCount: Int
    let holdoutSessionCount: Int
    let trainSamples: Int
    let calibrationSamples: Int
    let holdoutSamples: Int
    let selectedL2: Double
    let calibrationPrevalence: Double
    let holdoutPrevalence: Double
    let noSkillBrier: Double
    let metrics: BaselineClassificationMetrics

    var id: String {
        direction.rawValue
    }

    var brierSkill: Double {
        guard noSkillBrier > 0 else {
            return 0
        }

        return 1
            - (
                metrics.brierScore
                / noSkillBrier
            )
    }

    var passesProbabilityGate: Bool {
        brierSkill > 0
    }
}

struct SealedHoldoutEvaluation:
    Codable,
    Sendable {

    let architectureID: String
    let symbol: String
    let evaluatedAt: Date
    let holdoutStart: Date
    let holdoutEnd: Date
    let signalMode: String
    let directions:
        [SealedHoldoutDirectionResult]

    var preliminaryPass: Bool {
        guard !directions.isEmpty else {
            return false
        }

        return directions.allSatisfy {
            $0.passesProbabilityGate
        }
    }
}

enum BaselineModelEngine {
    static let coreFeatureNames = [
        "minuteOfSession",
        "sessionProgress",
        "return1",
        "return5",
        "return15",
        "return30",
        "return60",
        "rangePct",
        "atr14Pct",
        "realizedVol20",
        "volumeZ20",
        "distanceToSMA20",
        "distanceToSMA50",
        "distanceToSessionHigh",
        "distanceToSessionLow",
        "distanceToSessionVWAP"
    ]

    static let selfRegimeFeatureNames = [
        "sessionReturn",
        "returnFromPreviousSession",
        "previousSessionReturn",
        "previous3SessionReturn",
        "previous5SessionReturn",
        "prior3SessionVolatility"
    ]

    static let marketContextFeatureNames = [
        "spyReturn5",
        "spyReturn15",
        "spyReturn60",
        "spySessionReturn",
        "iwmReturn5",
        "iwmReturn15",
        "iwmReturn60",
        "iwmSessionReturn",
        "vixyReturn5",
        "vixyReturn15",
        "vixyReturn60",
        "vixySessionReturn"
    ]

    static func runExperiment(
        symbol: String,
        lockedPolicy:
            LockedLabelPolicyRecord,
        rows: [ResearchRow],
        folds: [WalkForwardFold],
        contextBars:
            [String: [MarketBar]]
    ) -> BaselineExperimentResult {
        let selfRegime =
            buildSelfRegimeFeatures(
                rows: rows
            )

        let marketContext =
            buildMarketContextFeatures(
                rows: rows,
                contextBars:
                    contextBars
            )

        let marketCoverage =
            rows.isEmpty
            ? 0
            : Double(
                marketContext.count
            )
            / Double(rows.count)

        var candidates:
            [BaselineRunResult] = []

        candidates.append(
            run(
                variant: .core16,
                symbol: symbol,
                lockedPolicy:
                    lockedPolicy,
                rows: rows,
                folds: folds,
                selfRegime:
                    [:],
                marketContext:
                    [:],
                contextCoverage: 1
            )
        )

        candidates.append(
            run(
                variant:
                    .selfRegime22,
                symbol: symbol,
                lockedPolicy:
                    lockedPolicy,
                rows: rows,
                folds: folds,
                selfRegime:
                    selfRegime,
                marketContext:
                    [:],
                contextCoverage: 1
            )
        )

        if marketCoverage >= 0.70 {
            candidates.append(
                run(
                    variant:
                        .marketContext28,
                    symbol: symbol,
                    lockedPolicy:
                        lockedPolicy,
                    rows: rows,
                    folds: folds,
                    selfRegime:
                        [:],
                    marketContext:
                        marketContext,
                    contextCoverage:
                        marketCoverage
                )
            )
        }

        let recommended =
            candidates.max {
                if $0.combinedDevelopmentScore
                    == $1.combinedDevelopmentScore {

                    return (
                        $0.meanLongSkill
                        + $0.meanShortSkill
                    )
                    < (
                        $1.meanLongSkill
                        + $1.meanShortSkill
                    )
                }

                return $0
                    .combinedDevelopmentScore
                    < $1
                        .combinedDevelopmentScore
            }

        return BaselineExperimentResult(
            symbol: symbol,
            generatedAt: Date(),
            candidates:
                candidates,
            recommendedVariant:
                recommended?
                    .variant
        )
    }

    static func runSealedHoldout(
        architectureID: String,
        symbol: String,
        signalMode: String,
        lockedPolicy:
            LockedLabelPolicyRecord,
        rows: [ResearchRow],
        holdoutStart: Date,
        holdoutEnd: Date,
        longVariant:
            BaselineFeatureVariant?,
        shortVariant:
            BaselineFeatureVariant?,
        contextBars:
            [String: [MarketBar]]
    ) -> SealedHoldoutEvaluation? {
        let developmentRows =
            rows.filter {
                $0.timestamp
                    < holdoutStart
            }

        let holdoutRows =
            rows.filter {
                $0.timestamp
                    >= holdoutStart
                && $0.timestamp
                    <= holdoutEnd
            }

        let developmentSessions =
            orderedSessions(
                developmentRows
            )

        let holdoutSessions =
            orderedSessions(
                holdoutRows
            )

        guard
            developmentSessions.count >= 12,
            holdoutSessions.count >= 3
        else {
            return nil
        }

        let calibrationCount =
            min(
                developmentSessions.count - 8,
                max(
                    5,
                    Int(
                        round(
                            Double(
                                developmentSessions.count
                            )
                            * 0.20
                        )
                    )
                )
            )

        guard
            calibrationCount >= 3,
            developmentSessions.count
                - calibrationCount
                >= 8
        else {
            return nil
        }

        let splitIndex =
            developmentSessions.count
            - calibrationCount

        let trainRows =
            developmentSessions[
                0..<splitIndex
            ]
            .flatMap {
                $0
            }

        let calibrationRows =
            developmentSessions[
                splitIndex
                    ..< developmentSessions.count
            ]
            .flatMap {
                $0
            }

        let selfRegime =
            buildSelfRegimeFeatures(
                rows: rows
            )

        let marketContext =
            buildMarketContextFeatures(
                rows: rows,
                contextBars:
                    contextBars
            )

        var directionResults:
            [SealedHoldoutDirectionResult] = []

        if let longVariant,
           let result =
            runSealedDirection(
                direction: .long,
                variant:
                    longVariant,
                trainRows:
                    trainRows,
                calibrationRows:
                    calibrationRows,
                holdoutRows:
                    holdoutRows,
                trainSessionCount:
                    splitIndex,
                calibrationSessionCount:
                    calibrationCount,
                holdoutSessionCount:
                    holdoutSessions.count,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            ) {

            directionResults.append(
                result
            )
        }

        if let shortVariant,
           let result =
            runSealedDirection(
                direction: .short,
                variant:
                    shortVariant,
                trainRows:
                    trainRows,
                calibrationRows:
                    calibrationRows,
                holdoutRows:
                    holdoutRows,
                trainSessionCount:
                    splitIndex,
                calibrationSessionCount:
                    calibrationCount,
                holdoutSessionCount:
                    holdoutSessions.count,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            ) {

            directionResults.append(
                result
            )
        }

        guard
            !directionResults.isEmpty
        else {
            return nil
        }

        return SealedHoldoutEvaluation(
            architectureID:
                architectureID,
            symbol: symbol,
            evaluatedAt: Date(),
            holdoutStart:
                holdoutStart,
            holdoutEnd:
                holdoutEnd,
            signalMode:
                signalMode,
            directions:
                directionResults
        )
    }

    private static func runSealedDirection(
        direction:
            BaselineDirection,
        variant:
            BaselineFeatureVariant,
        trainRows: [ResearchRow],
        calibrationRows:
            [ResearchRow],
        holdoutRows: [ResearchRow],
        trainSessionCount: Int,
        calibrationSessionCount: Int,
        holdoutSessionCount: Int,
        selfRegime:
            [String: [Double]],
        marketContext:
            [String: [Double]]
    ) -> SealedHoldoutDirectionResult? {
        let rawTrain =
            examples(
                rows: trainRows,
                direction:
                    direction,
                variant:
                    variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let rawCalibration =
            examples(
                rows:
                    calibrationRows,
                direction:
                    direction,
                variant:
                    variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let rawHoldout =
            examples(
                rows: holdoutRows,
                direction:
                    direction,
                variant:
                    variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        guard
            rawTrain.count >= 300,
            rawCalibration.count >= 100,
            rawHoldout.count >= 100
        else {
            return nil
        }

        let selectedL2 =
            selectRegularization(
                trainRows:
                    trainRows,
                direction:
                    direction,
                variant:
                    variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let standardizer =
            fitStandardizer(
                rawTrain.map {
                    $0.x
                }
            )

        let train =
            rawTrain.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let calibration =
            rawCalibration.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let holdout =
            rawHoldout.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let model =
            trainLogistic(
                examples: train,
                l2: selectedL2,
                epochs: 60
            )

        let calibrationRawProbabilities =
            calibration.map {
                model.probability(
                    $0.x
                )
            }

        let calibrationLabels =
            calibration.map {
                $0.y
            }

        let scaler =
            fitPlattScaler(
                probabilities:
                    calibrationRawProbabilities,
                labels:
                    calibrationLabels
            )

        let calibrationProbabilities =
            calibrationRawProbabilities
                .map {
                    scaler.probability(
                        rawProbability:
                            $0
                    )
                }

        let threshold =
            selectThreshold(
                probabilities:
                    calibrationProbabilities,
                labels:
                    calibrationLabels
            )

        let holdoutProbabilities =
            holdout.map {
                scaler.probability(
                    rawProbability:
                        model.probability(
                            $0.x
                        )
                )
            }

        let holdoutLabels =
            holdout.map {
                $0.y
            }

        let calibrationPrevalence =
            prevalence(
                calibration
            )

        let holdoutPrevalence =
            prevalence(
                holdout
            )

        let noSkillBrier =
            constantBrier(
                probability:
                    calibrationPrevalence,
                labels:
                    holdoutLabels
            )

        let metrics =
            classificationMetrics(
                probabilities:
                    holdoutProbabilities,
                labels:
                    holdoutLabels,
                threshold:
                    threshold
            )

        return SealedHoldoutDirectionResult(
            direction:
                direction,
            variant:
                variant,
            trainSessionCount:
                trainSessionCount,
            calibrationSessionCount:
                calibrationSessionCount,
            holdoutSessionCount:
                holdoutSessionCount,
            trainSamples:
                train.count,
            calibrationSamples:
                calibration.count,
            holdoutSamples:
                holdout.count,
            selectedL2:
                selectedL2,
            calibrationPrevalence:
                calibrationPrevalence,
            holdoutPrevalence:
                holdoutPrevalence,
            noSkillBrier:
                noSkillBrier,
            metrics:
                metrics
        )
    }

    private static func orderedSessions(
        _ rows: [ResearchRow]
    ) -> [[ResearchRow]] {
        Array(
            Dictionary(
                grouping:
                    rows.sorted {
                        $0.timestamp
                            < $1.timestamp
                    },
                by: {
                    $0.sessionKey
                }
            )
            .values
        )
        .map {
            $0.sorted {
                $0.timestamp
                    < $1.timestamp
            }
        }
        .sorted {
            ($0.first?.timestamp
                ?? .distantPast)
            < ($1.first?.timestamp
                ?? .distantPast)
        }
    }

    private struct Example {
        let x: [Double]
        let y: Double
    }

    private struct Standardizer {
        let mean: [Double]
        let scale: [Double]

        func transform(
            _ values: [Double]
        ) -> [Double] {
            zip(
                zip(values, mean),
                scale
            )
            .map {
                pair,
                denominator in

                let (
                    value,
                    center
                ) = pair

                return (
                    value - center
                )
                / denominator
            }
        }
    }

    private struct LogisticModel {
        let weights: [Double]
        let bias: Double

        func probability(
            _ x: [Double]
        ) -> Double {
            var z = bias

            for index in x.indices {
                z +=
                    weights[index]
                    * x[index]
            }

            return sigmoid(z)
        }
    }

    private struct PlattScaler {
        let slope: Double
        let intercept: Double

        func probability(
            rawProbability:
                Double
        ) -> Double {
            let raw =
                min(
                    max(
                        rawProbability,
                        0.000_001
                    ),
                    0.999_999
                )

            let logit =
                log(
                    raw / (1 - raw)
                )

            return sigmoid(
                slope * logit
                + intercept
            )
        }
    }

    private static func run(
        variant:
            BaselineFeatureVariant,
        symbol: String,
        lockedPolicy:
            LockedLabelPolicyRecord,
        rows: [ResearchRow],
        folds: [WalkForwardFold],
        selfRegime:
            [String: [Double]],
        marketContext:
            [String: [Double]],
        contextCoverage: Double
    ) -> BaselineRunResult {
        var results:
            [BaselineFoldResult] = []

        for fold in folds {
            for direction in [
                BaselineDirection.long,
                BaselineDirection.short
            ] {
                if let result =
                    runFold(
                        fold: fold,
                        direction:
                            direction,
                        rows: rows,
                        variant: variant,
                        selfRegime:
                            selfRegime,
                        marketContext:
                            marketContext
                    ) {

                    results.append(
                        result
                    )
                }
            }
        }

        return BaselineRunResult(
            variant: variant,
            symbol: symbol,
            generatedAt: Date(),
            lockedPolicyID:
                lockedPolicy.policy.id,
            lockedPolicyName:
                lockedPolicy.policy.name,
            featureNames:
                featureNames(
                    for: variant
                ),
            contextCoverage:
                contextCoverage,
            folds: results
        )
    }

    private static func featureNames(
        for variant:
            BaselineFeatureVariant
    ) -> [String] {
        switch variant {
        case .core16:
            return coreFeatureNames

        case .selfRegime22:
            return coreFeatureNames
                + selfRegimeFeatureNames

        case .marketContext28:
            return coreFeatureNames
                + marketContextFeatureNames
        }
    }

    private static func runFold(
        fold: WalkForwardFold,
        direction:
            BaselineDirection,
        rows: [ResearchRow],
        variant:
            BaselineFeatureVariant,
        selfRegime:
            [String: [Double]],
        marketContext:
            [String: [Double]]
    ) -> BaselineFoldResult? {
        let trainRows =
            rows.filter {
                $0.timestamp
                    >= fold.trainStart
                && $0.timestamp
                    <= fold.trainEnd
            }

        let validationRows =
            rows.filter {
                $0.timestamp
                    >= fold.validationStart
                && $0.timestamp
                    <= fold.validationEnd
            }

        let testRows =
            rows.filter {
                $0.timestamp
                    >= fold.testStart
                && $0.timestamp
                    <= fold.testEnd
            }

        let rawTrain =
            examples(
                rows: trainRows,
                direction: direction,
                variant: variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let rawValidation =
            examples(
                rows: validationRows,
                direction: direction,
                variant: variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let rawTest =
            examples(
                rows: testRows,
                direction: direction,
                variant: variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        guard
            rawTrain.count >= 200,
            rawValidation.count >= 50,
            rawTest.count >= 50
        else {
            return nil
        }

        let selectedL2 =
            selectRegularization(
                trainRows: trainRows,
                direction: direction,
                variant: variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let standardizer =
            fitStandardizer(
                rawTrain.map {
                    $0.x
                }
            )

        let train =
            rawTrain.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let validation =
            rawValidation.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let test =
            rawTest.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let model =
            trainLogistic(
                examples: train,
                l2: selectedL2,
                epochs: 60
            )

        let trainPrevalence =
            prevalence(train)

        let validationPrevalence =
            prevalence(validation)

        let testPrevalence =
            prevalence(test)

        let validationRawProbabilities =
            validation.map {
                model.probability(
                    $0.x
                )
            }

        let validationLabels =
            validation.map {
                $0.y
            }

        let platt =
            fitPlattScaler(
                probabilities:
                    validationRawProbabilities,
                labels:
                    validationLabels
            )

        let validationCalibrated =
            validationRawProbabilities
                .map {
                    platt.probability(
                        rawProbability: $0
                    )
                }

        let threshold =
            selectThreshold(
                probabilities:
                    validationCalibrated,
                labels:
                    validationLabels
            )

        let testRawProbabilities =
            test.map {
                model.probability(
                    $0.x
                )
            }

        let testCalibrated =
            testRawProbabilities.map {
                platt.probability(
                    rawProbability: $0
                )
            }

        let testLabels =
            test.map {
                $0.y
            }

        let trainPriorBrier =
            constantBrier(
                probability:
                    trainPrevalence,
                labels:
                    testLabels
            )

        let validationPriorBrier =
            constantBrier(
                probability:
                    validationPrevalence,
                labels:
                    testLabels
            )

        let rawMetrics =
            classificationMetrics(
                probabilities:
                    testRawProbabilities,
                labels:
                    testLabels,
                threshold:
                    threshold
            )

        let calibratedMetrics =
            classificationMetrics(
                probabilities:
                    testCalibrated,
                labels:
                    testLabels,
                threshold:
                    threshold
            )

        return BaselineFoldResult(
            fold: fold.fold,
            direction:
                direction,
            trainSamples:
                train.count,
            validationSamples:
                validation.count,
            testSamples:
                test.count,
            trainPrevalence:
                trainPrevalence,
            validationPrevalence:
                validationPrevalence,
            testPrevalence:
                testPrevalence,
            validationThreshold:
                threshold,
            selectedL2:
                selectedL2,
            trainPriorTestBrier:
                trainPriorBrier,
            validationPriorTestBrier:
                validationPriorBrier,
            rawLogisticTest:
                rawMetrics,
            calibratedTest:
                calibratedMetrics
        )
    }

    private static func examples(
        rows: [ResearchRow],
        direction:
            BaselineDirection,
        variant:
            BaselineFeatureVariant,
        selfRegime:
            [String: [Double]],
        marketContext:
            [String: [Double]]
    ) -> [Example] {
        rows.compactMap { row in
            let outcome:
                ResearchOutcome

            switch direction {
            case .long:
                outcome =
                    row.longOutcome

            case .short:
                outcome =
                    row.shortOutcome
            }

            guard outcome
                    != .ambiguous
            else {
                return nil
            }

            let extras:
                [Double]

            switch variant {
            case .core16:
                extras = []

            case .selfRegime22:
                guard
                    let values =
                        selfRegime[
                            row.id
                        ]
                else {
                    return nil
                }

                extras = values

            case .marketContext28:
                guard
                    let values =
                        marketContext[
                            row.id
                        ]
                else {
                    return nil
                }

                extras = values
            }

            return Example(
                x:
                    coreFeatures(row)
                    + extras,
                y:
                    outcome == .target
                    ? 1
                    : 0
            )
        }
    }

    private static func coreFeatures(
        _ row: ResearchRow
    ) -> [Double] {
        [
            Double(
                row.minuteOfSession
            ),
            row.sessionProgress,
            row.return1,
            row.return5,
            row.return15,
            row.return30,
            row.return60,
            row.rangePct,
            row.atr14Pct,
            row.realizedVol20,
            row.volumeZ20 ?? 0,
            row.distanceToSMA20,
            row.distanceToSMA50,
            row.distanceToSessionHigh,
            row.distanceToSessionLow,
            row.distanceToSessionVWAP
                ?? 0
        ]
    }

    private static func buildSelfRegimeFeatures(
        rows: [ResearchRow]
    ) -> [String: [Double]] {
        let grouped =
            Dictionary(
                grouping:
                    rows.sorted {
                        $0.timestamp
                            < $1.timestamp
                    },
                by: {
                    $0.sessionKey
                }
            )

        let orderedSessions =
            grouped.values
                .map {
                    $0.sorted {
                        $0.timestamp
                            < $1.timestamp
                    }
                }
                .sorted {
                    ($0.first?.timestamp
                        ?? .distantPast)
                    < ($1.first?.timestamp
                        ?? .distantPast)
                }

        var priorCloses:
            [Double] = []

        var priorVolatility:
            [Double] = []

        var result:
            [String: [Double]] = [:]

        for sessionRows in
            orderedSessions {

            guard
                let first =
                    sessionRows.first,
                let last =
                    sessionRows.last
            else {
                continue
            }

            let previousClose =
                priorCloses.last

            let previousSessionReturn:
                Double

            if priorCloses.count >= 2 {
                previousSessionReturn =
                    safeReturn(
                        priorCloses[
                            priorCloses.count - 1
                        ],
                        priorCloses[
                            priorCloses.count - 2
                        ]
                    )

            } else {
                previousSessionReturn = 0
            }

            let previous3SessionReturn =
                multiSessionReturn(
                    closes:
                        priorCloses,
                    transitions: 3
                )

            let previous5SessionReturn =
                multiSessionReturn(
                    closes:
                        priorCloses,
                    transitions: 5
                )

            let prior3Volatility =
                averageSuffix(
                    priorVolatility,
                    count: 3
                )

            for row in sessionRows {
                let sessionReturn =
                    safeReturn(
                        row.close,
                        first.close
                    )

                let fromPreviousSession =
                    previousClose
                    .map {
                        safeReturn(
                            row.close,
                            $0
                        )
                    }
                    ?? 0

                result[row.id] = [
                    sessionReturn,
                    fromPreviousSession,
                    previousSessionReturn,
                    previous3SessionReturn,
                    previous5SessionReturn,
                    prior3Volatility
                ]
            }

            priorCloses.append(
                last.close
            )

            let sessionVolatility =
                sessionRows
                    .map {
                        $0.realizedVol20
                    }
                    .reduce(
                        0,
                        +
                    )
                / Double(
                    max(
                        sessionRows.count,
                        1
                    )
                )

            priorVolatility.append(
                sessionVolatility
            )
        }

        return result
    }

    private static func buildMarketContextFeatures(
        rows: [ResearchRow],
        contextBars:
            [String: [MarketBar]]
    ) -> [String: [Double]] {
        let requiredSymbols = [
            "SPY",
            "IWM",
            "VIXY"
        ]

        var featureBySymbol:
            [String: [Date: [Double]]] = [:]

        for symbol in requiredSymbols {
            guard
                let bars =
                    contextBars[symbol],
                !bars.isEmpty
            else {
                return [:]
            }

            featureBySymbol[symbol] =
                marketFeaturesByTimestamp(
                    bars: bars
                )
        }

        var result:
            [String: [Double]] = [:]

        for row in rows {
            guard
                let spy =
                    featureBySymbol["SPY"]?[
                        row.timestamp
                    ],
                let iwm =
                    featureBySymbol["IWM"]?[
                        row.timestamp
                    ],
                let vixy =
                    featureBySymbol["VIXY"]?[
                        row.timestamp
                    ]
            else {
                continue
            }

            result[row.id] =
                spy + iwm + vixy
        }

        return result
    }

    private static func marketFeaturesByTimestamp(
        bars: [MarketBar]
    ) -> [Date: [Double]] {
        let timezone =
            TimeZone(
                identifier:
                    "America/New_York"
            )
            ?? .current

        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.timeZone =
            timezone

        let regularBars =
            bars.filter { bar in
                let components =
                    calendar.dateComponents(
                        [.hour, .minute],
                        from:
                            bar.timestamp
                    )

                guard
                    let hour =
                        components.hour,
                    let minute =
                        components.minute
                else {
                    return false
                }

                let minuteOfDay =
                    hour * 60 + minute

                return minuteOfDay >= 570
                    && minuteOfDay < 960
            }
            .sorted {
                $0.timestamp
                    < $1.timestamp
            }

        let grouped =
            Dictionary(
                grouping:
                    regularBars
            ) { bar in
                let components =
                    calendar.dateComponents(
                        [.year, .month, .day],
                        from:
                            bar.timestamp
                    )

                return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            }

        var result:
            [Date: [Double]] = [:]

        for session in grouped.values {
            let ordered =
                session.sorted {
                    $0.timestamp
                        < $1.timestamp
                }

            guard
                let first =
                    ordered.first
            else {
                continue
            }

            for index in ordered.indices {
                guard index >= 60 else {
                    continue
                }

                let current =
                    ordered[index]

                result[
                    current.timestamp
                ] = [
                    safeReturn(
                        current.close,
                        ordered[
                            index - 5
                        ].close
                    ),
                    safeReturn(
                        current.close,
                        ordered[
                            index - 15
                        ].close
                    ),
                    safeReturn(
                        current.close,
                        ordered[
                            index - 60
                        ].close
                    ),
                    safeReturn(
                        current.close,
                        first.close
                    )
                ]
            }
        }

        return result
    }

    private static func multiSessionReturn(
        closes: [Double],
        transitions: Int
    ) -> Double {
        let required =
            transitions + 1

        guard
            closes.count >= required
        else {
            return 0
        }

        let end =
            closes[
                closes.count - 1
            ]

        let start =
            closes[
                closes.count - required
            ]

        return safeReturn(
            end,
            start
        )
    }

    private static func averageSuffix(
        _ values: [Double],
        count: Int
    ) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        let suffix =
            values.suffix(
                min(
                    count,
                    values.count
                )
            )

        return suffix.reduce(
            0,
            +
        )
        / Double(suffix.count)
    }

    private static func safeReturn(
        _ end: Double,
        _ start: Double
    ) -> Double {
        guard start != 0 else {
            return 0
        }

        return end / start - 1
    }

    private static func fitStandardizer(
        _ matrix: [[Double]]
    ) -> Standardizer {
        guard
            let first =
                matrix.first
        else {
            return Standardizer(
                mean: [],
                scale: []
            )
        }

        let featureCount =
            first.count

        var mean =
            Array(
                repeating: 0.0,
                count: featureCount
            )

        for row in matrix {
            for index in
                0..<featureCount {

                mean[index] +=
                    row[index]
            }
        }

        let denominator =
            Double(
                max(
                    matrix.count,
                    1
                )
            )

        for index in
            0..<featureCount {

            mean[index] /=
                denominator
        }

        var variance =
            Array(
                repeating: 0.0,
                count: featureCount
            )

        for row in matrix {
            for index in
                0..<featureCount {

                let delta =
                    row[index]
                    - mean[index]

                variance[index] +=
                    delta * delta
            }
        }

        var scale =
            variance.map {
                sqrt(
                    $0
                    / denominator
                )
            }

        for index in scale.indices {
            if !scale[index].isFinite
                || scale[index] < 1e-9 {

                scale[index] = 1
            }
        }

        return Standardizer(
            mean: mean,
            scale: scale
        )
    }

    private static func trainLogistic(
        examples: [Example],
        l2: Double,
        epochs: Int
    ) -> LogisticModel {
        guard
            let first =
                examples.first
        else {
            return LogisticModel(
                weights: [],
                bias: 0
            )
        }

        let featureCount =
            first.x.count

        var weights =
            Array(
                repeating: 0.0,
                count: featureCount
            )

        let prior =
            min(
                max(
                    prevalence(examples),
                    0.001
                ),
                0.999
            )

        var bias =
            log(
                prior
                / (1 - prior)
            )

        let learningRate = 0.06
        let n =
            Double(
                examples.count
            )

        for _ in 0..<epochs {
            if Task.isCancelled {
                break
            }

            var gradient =
                Array(
                    repeating: 0.0,
                    count: featureCount
                )

            var biasGradient = 0.0

            for example in examples {
                var z = bias

                for index in
                    0..<featureCount {

                    z +=
                        weights[index]
                        * example.x[index]
                }

                let probability =
                    sigmoid(z)

                let error =
                    probability
                    - example.y

                biasGradient +=
                    error

                for index in
                    0..<featureCount {

                    gradient[index] +=
                        error
                        * example.x[index]
                }
            }

            bias -=
                learningRate
                * (
                    biasGradient / n
                )

            for index in
                0..<featureCount {

                let regularized =
                    gradient[index] / n
                    + l2
                    * weights[index]

                weights[index] -=
                    learningRate
                    * regularized
            }
        }

        return LogisticModel(
            weights: weights,
            bias: bias
        )
    }

    private static func selectRegularization(
        trainRows: [ResearchRow],
        direction:
            BaselineDirection,
        variant:
            BaselineFeatureVariant,
        selfRegime:
            [String: [Double]],
        marketContext:
            [String: [Double]]
    ) -> Double {
        let orderedSessions =
            Array(
                Dictionary(
                    grouping:
                        trainRows.sorted {
                            $0.timestamp
                                < $1.timestamp
                        },
                    by: {
                        $0.sessionKey
                    }
                )
                .values
            )
            .map {
                $0.sorted {
                    $0.timestamp
                        < $1.timestamp
                }
            }
            .sorted {
                ($0.first?.timestamp
                    ?? .distantPast)
                < ($1.first?.timestamp
                    ?? .distantPast)
            }

        guard orderedSessions.count >= 6 else {
            return 0.01
        }

        let innerTrainCount =
            min(
                orderedSessions.count - 2,
                max(
                    4,
                    Int(
                        floor(
                            Double(
                                orderedSessions.count
                            )
                            * 0.75
                        )
                    )
                )
            )

        let innerTrainRows =
            orderedSessions[
                0..<innerTrainCount
            ]
            .flatMap {
                $0
            }

        let innerValidationRows =
            orderedSessions[
                innerTrainCount
                    ..< orderedSessions.count
            ]
            .flatMap {
                $0
            }

        let rawInnerTrain =
            examples(
                rows: innerTrainRows,
                direction: direction,
                variant: variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        let rawInnerValidation =
            examples(
                rows:
                    innerValidationRows,
                direction: direction,
                variant: variant,
                selfRegime:
                    selfRegime,
                marketContext:
                    marketContext
            )

        guard
            rawInnerTrain.count >= 150,
            rawInnerValidation.count >= 50
        else {
            return 0.01
        }

        let standardizer =
            fitStandardizer(
                rawInnerTrain.map {
                    $0.x
                }
            )

        let innerTrain =
            rawInnerTrain.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let innerValidation =
            rawInnerValidation.map {
                Example(
                    x:
                        standardizer
                            .transform(
                                $0.x
                            ),
                    y: $0.y
                )
            }

        let validationLabels =
            innerValidation.map {
                $0.y
            }

        let candidates = [
            0.001,
            0.05,
            0.25,
            1.00
        ]

        let tuningTrain =
            evenlySample(
                innerTrain,
                maximumCount: 2_000
            )

        var bestL2 = 0.05
        var bestBrier =
            Double.greatestFiniteMagnitude

        for l2 in candidates {
            let model =
                trainLogistic(
                    examples:
                        tuningTrain,
                    l2: l2,
                    epochs: 25
                )

            let probabilities =
                innerValidation.map {
                    model.probability(
                        $0.x
                    )
                }

            let score =
                brier(
                    probabilities:
                        probabilities,
                    labels:
                        validationLabels
                )

            if score < bestBrier {
                bestBrier = score
                bestL2 = l2
            }
        }

        return bestL2
    }

    private static func evenlySample(
        _ examples: [Example],
        maximumCount: Int
    ) -> [Example] {
        guard
            maximumCount > 0,
            examples.count > maximumCount
        else {
            return examples
        }

        let step =
            Double(examples.count - 1)
            / Double(maximumCount - 1)

        return (0..<maximumCount).map {
            index in

            let sourceIndex =
                min(
                    examples.count - 1,
                    Int(
                        round(
                            Double(index)
                            * step
                        )
                    )
                )

            return examples[sourceIndex]
        }
    }

    private static func fitPlattScaler(
        probabilities: [Double],
        labels: [Double]
    ) -> PlattScaler {
        let count =
            min(
                probabilities.count,
                labels.count
            )

        guard count > 0 else {
            return PlattScaler(
                slope: 1,
                intercept: 0
            )
        }

        var slope = 1.0
        var intercept = 0.0

        let epochs = 160
        let learningRate = 0.03
        let l2 = 0.001
        let n = Double(count)

        for _ in 0..<epochs {
            var slopeGradient = 0.0
            var interceptGradient = 0.0

            for index in 0..<count {
                let raw =
                    min(
                        max(
                            probabilities[index],
                            0.000_001
                        ),
                        0.999_999
                    )

                let logit =
                    log(
                        raw / (1 - raw)
                    )

                let prediction =
                    sigmoid(
                        slope * logit
                        + intercept
                    )

                let error =
                    prediction
                    - labels[index]

                slopeGradient +=
                    error * logit

                interceptGradient +=
                    error
            }

            slope -=
                learningRate
                * (
                    slopeGradient / n
                    + l2 * slope
                )

            intercept -=
                learningRate
                * (
                    interceptGradient / n
                )
        }

        return PlattScaler(
            slope: slope,
            intercept: intercept
        )
    }

    private static func selectThreshold(
        probabilities: [Double],
        labels: [Double]
    ) -> Double {
        var bestThreshold = 0.5
        var bestF1 = -1.0
        var bestPrecision = -1.0

        var threshold = 0.05

        while threshold <= 0.60 {
            let metrics =
                classificationMetrics(
                    probabilities:
                        probabilities,
                    labels: labels,
                    threshold:
                        threshold
                )

            if metrics.f1 > bestF1
                || (
                    abs(
                        metrics.f1
                        - bestF1
                    ) < 1e-12
                    && metrics.precision
                        > bestPrecision
                ) {

                bestF1 =
                    metrics.f1

                bestPrecision =
                    metrics.precision

                bestThreshold =
                    threshold
            }

            threshold += 0.025
        }

        return bestThreshold
    }

    private static func classificationMetrics(
        probabilities: [Double],
        labels: [Double],
        threshold: Double
    ) -> BaselineClassificationMetrics {
        let count =
            min(
                probabilities.count,
                labels.count
            )

        guard count > 0 else {
            return BaselineClassificationMetrics(
                samples: 0,
                prevalence: 0,
                meanProbability: 0,
                threshold:
                    threshold,
                brierScore: 0,
                expectedCalibrationError: 0,
                precision: 0,
                recall: 0,
                f1: 0,
                accuracy: 0
            )
        }

        var tp = 0
        var fp = 0
        var tn = 0
        var fn = 0
        var positives = 0
        var probabilitySum = 0.0

        for index in 0..<count {
            let actual =
                labels[index] >= 0.5

            let predicted =
                probabilities[index]
                >= threshold

            probabilitySum +=
                probabilities[index]

            if actual {
                positives += 1
            }

            switch (
                predicted,
                actual
            ) {
            case (true, true):
                tp += 1

            case (true, false):
                fp += 1

            case (false, true):
                fn += 1

            case (false, false):
                tn += 1
            }
        }

        let precision =
            Double(tp)
            / Double(
                max(
                    tp + fp,
                    1
                )
            )

        let recall =
            Double(tp)
            / Double(
                max(
                    tp + fn,
                    1
                )
            )

        let f1 =
            precision + recall > 0
            ? 2
                * precision
                * recall
                / (
                    precision
                    + recall
                )
            : 0

        let accuracy =
            Double(
                tp + tn
            )
            / Double(count)

        return BaselineClassificationMetrics(
            samples: count,
            prevalence:
                Double(positives)
                / Double(count),
            meanProbability:
                probabilitySum
                / Double(count),
            threshold:
                threshold,
            brierScore:
                brier(
                    probabilities:
                        Array(
                            probabilities
                                .prefix(count)
                        ),
                    labels:
                        Array(
                            labels
                                .prefix(count)
                        )
                ),
            expectedCalibrationError:
                calibrationError(
                    probabilities:
                        Array(
                            probabilities
                                .prefix(count)
                        ),
                    labels:
                        Array(
                            labels
                                .prefix(count)
                        )
                ),
            precision:
                precision,
            recall: recall,
            f1: f1,
            accuracy:
                accuracy
        )
    }

    private static func prevalence(
        _ examples: [Example]
    ) -> Double {
        guard !examples.isEmpty else {
            return 0
        }

        return examples.reduce(
            0
        ) {
            $0 + $1.y
        }
        / Double(examples.count)
    }

    private static func constantBrier(
        probability: Double,
        labels: [Double]
    ) -> Double {
        brier(
            probabilities:
                Array(
                    repeating:
                        probability,
                    count:
                        labels.count
                ),
            labels:
                labels
        )
    }

    private static func brier(
        probabilities: [Double],
        labels: [Double]
    ) -> Double {
        let count =
            min(
                probabilities.count,
                labels.count
            )

        guard count > 0 else {
            return 0
        }

        var sum = 0.0

        for index in 0..<count {
            let delta =
                probabilities[index]
                - labels[index]

            sum +=
                delta * delta
        }

        return sum / Double(count)
    }

    private static func calibrationError(
        probabilities: [Double],
        labels: [Double]
    ) -> Double {
        let count =
            min(
                probabilities.count,
                labels.count
            )

        guard count > 0 else {
            return 0
        }

        let bins = 10
        var totalError = 0.0

        for bin in 0..<bins {
            let lower =
                Double(bin)
                / Double(bins)

            let upper =
                Double(bin + 1)
                / Double(bins)

            var binCount = 0
            var probabilitySum = 0.0
            var labelSum = 0.0

            for index in 0..<count {
                let probability =
                    probabilities[index]

                let inBin =
                    bin == bins - 1
                    ? (
                        probability >= lower
                        && probability <= upper
                    )
                    : (
                        probability >= lower
                        && probability < upper
                    )

                if inBin {
                    binCount += 1
                    probabilitySum +=
                        probability
                    labelSum +=
                        labels[index]
                }
            }

            guard binCount > 0 else {
                continue
            }

            let meanProbability =
                probabilitySum
                / Double(binCount)

            let observed =
                labelSum
                / Double(binCount)

            totalError +=
                Double(binCount)
                / Double(count)
                * abs(
                    meanProbability
                    - observed
                )
        }

        return totalError
    }

    private static func sigmoid(
        _ value: Double
    ) -> Double {
        let clamped =
            min(
                max(
                    value,
                    -35
                ),
                35
            )

        return 1
            / (
                1
                + exp(-clamped)
            )
    }
}
