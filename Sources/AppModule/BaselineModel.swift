import Foundation

enum BaselineDirection:
    String,
    Codable,
    Sendable {

    case long = "LONG"
    case short = "SHORT"
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
    Sendable {

    let symbol: String
    let generatedAt: Date
    let lockedPolicyID: String
    let lockedPolicyName: String
    let featureNames: [String]
    let folds: [BaselineFoldResult]

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

enum BaselineModelEngine {
    static let featureNames = [
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

    static func run(
        symbol: String,
        lockedPolicy:
            LockedLabelPolicyRecord,
        rows: [ResearchRow],
        folds: [WalkForwardFold]
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
                        rows: rows
                    ) {

                    results.append(
                        result
                    )
                }
            }
        }

        return BaselineRunResult(
            symbol: symbol,
            generatedAt: Date(),
            lockedPolicyID:
                lockedPolicy.policy.id,
            lockedPolicyName:
                lockedPolicy.policy.name,
            featureNames:
                featureNames,
            folds: results
        )
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

    private static func runFold(
        fold: WalkForwardFold,
        direction:
            BaselineDirection,
        rows: [ResearchRow]
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
                direction: direction
            )

        let rawValidation =
            examples(
                rows: validationRows,
                direction: direction
            )

        let rawTest =
            examples(
                rows: testRows,
                direction: direction
            )

        guard
            rawTrain.count >= 200,
            rawValidation.count >= 50,
            rawTest.count >= 50
        else {
            return nil
        }

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
                examples: train
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
            BaselineDirection
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

            return Example(
                x: features(row),
                y:
                    outcome == .target
                    ? 1
                    : 0
            )
        }
    }

    private static func features(
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
        examples: [Example]
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

        let epochs = 120
        let learningRate = 0.06
        let l2 = 0.001
        let n =
            Double(
                examples.count
            )

        for _ in 0..<epochs {
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
