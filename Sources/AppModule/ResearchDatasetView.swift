import SwiftUI

struct ResearchDatasetView: View {
    @EnvironmentObject
    private var store: AppStore

    let onClose: () -> Void

    init(
        onClose: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
    }

    private let labelConfig =
        ResearchLabelConfig.defaultIntraday

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected asset") {
                    LabeledContent(
                        "Symbol",
                        value: store.selectedAsset?.symbol
                            ?? "None"
                    )

                    LabeledContent(
                        "Local 1m bars",
                        value: String(
                            store.storageStats.count
                        )
                    )

                    LabeledContent(
                        "Earliest",
                        value: formatted(
                            store.storageStats.earliest
                        )
                    )

                    LabeledContent(
                        "Latest",
                        value: formatted(
                            store.storageStats.latest
                        )
                    )
                }

                Section("Dataset policy") {
                    LabeledContent(
                        "Target",
                        value: percent(
                            labelConfig.targetPct
                        )
                    )

                    LabeledContent(
                        "Stop",
                        value: percent(
                            labelConfig.stopPct
                        )
                    )

                    LabeledContent(
                        "Label horizon",
                        value:
                            "\(labelConfig.horizonMinutes) min"
                    )

                    LabeledContent(
                        "Session",
                        value:
                            store.selectedAsset?.assetClass == .crypto
                            ? "UTC 24/7 day"
                            : "Regular 09:30–16:00"
                    )

                    Text(
                        "Features are causal: every row uses only information available at or before that timestamp. Labels look forward only for evaluation/training targets."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        "If target and stop are both touched inside the same 1-minute candle, the outcome is marked ambiguous instead of guessing intrabar order."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Build") {
                    if store.isBuildingResearchDataset {
                        ProgressView()
                    }

                    Text(store.researchMessage)
                        .font(.callout)
                        .textSelection(.enabled)

                    Button {
                        Task {
                            await store.loadLocalBars()
                            await store.buildResearchDataset()
                        }
                    } label: {
                        Label(
                            "Build Research Dataset",
                            systemImage: "tablecells"
                        )
                    }
                    .disabled(
                        store.isBuildingResearchDataset
                        || store.isDownloadingHistory
                        || store.isValidatingUniverse
                    )

                    if store.storageStats.count < 300 {
                        Text(
                            "Local storage currently reports \(store.storageStats.count) bars. The build button now refreshes storage first; if data is still missing, use Historical Data to download it."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if let summary = store.researchSummary {
                    Section("Dataset summary") {
                        LabeledContent(
                            "Rows",
                            value: String(
                                summary.rowCount
                            )
                        )

                        LabeledContent(
                            "Features",
                            value: String(
                                summary.featureCount
                            )
                        )

                        LabeledContent(
                            "Raw bars",
                            value: String(
                                summary.rawBarCount
                            )
                        )

                        LabeledContent(
                            "Eligible session bars",
                            value: String(
                                summary.eligibleBarCount
                            )
                        )

                        LabeledContent(
                            "Sessions",
                            value: String(
                                summary.sessionCount
                            )
                        )

                        LabeledContent(
                            "First row",
                            value: formatted(
                                summary.earliestRow
                            )
                        )

                        LabeledContent(
                            "Last row",
                            value: formatted(
                                summary.latestRow
                            )
                        )

                        LabeledContent(
                            "Long target rate",
                            value: percent(
                                summary.longTargetRate
                            )
                        )

                        LabeledContent(
                            "Short target rate",
                            value: percent(
                                summary.shortTargetRate
                            )
                        )

                        LabeledContent(
                            "Long timeout rate",
                            value: percent(
                                summary.longTimeoutRate
                            )
                        )

                        LabeledContent(
                            "Short timeout rate",
                            value: percent(
                                summary.shortTimeoutRate
                            )
                        )

                        LabeledContent(
                            "Ambiguous rate",
                            value: percent(
                                summary.ambiguousRate
                            )
                        )
                    }
                }

                Section("Walk-forward validation") {
                    if store.researchFolds.isEmpty {
                        if let summary = store.researchSummary,
                           summary.sessionCount < 18 {

                            Text(
                                "Only \(summary.sessionCount) complete sessions are available. Model training is intentionally blocked until at least 18 independent sessions exist. Download about 60 calendar days of history for a more useful baseline."
                            )
                            .foregroundStyle(.orange)

                        } else {
                            Text(
                                "Build the dataset first. With enough history, the app creates three expanding walk-forward folds split only on full-session boundaries."
                            )
                            .foregroundStyle(.secondary)
                        }

                    } else {
                        ForEach(
                            store.researchFolds
                        ) { fold in
                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                Text(
                                    "Fold \(fold.fold)"
                                )
                                .font(.headline)

                                LabeledContent(
                                    "Train",
                                    value:
                                        "\(fold.trainCount) rows"
                                )

                                Text(
                                    "\(formatted(fold.trainStart)) → \(formatted(fold.trainEnd))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                LabeledContent(
                                    "Validation",
                                    value:
                                        "\(fold.validationCount) rows"
                                )

                                Text(
                                    "\(formatted(fold.validationStart)) → \(formatted(fold.validationEnd))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                LabeledContent(
                                    "Test",
                                    value:
                                        "\(fold.testCount) rows"
                                )

                                Text(
                                    "\(formatted(fold.testStart)) → \(formatted(fold.testEnd))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(
                                .vertical,
                                4
                            )
                        }
                    }
                }

                if let summary = store.researchSummary {
                    Section("Training readiness") {
                        if summary.sessionCount < 18 {
                            Text(
                                "NOT READY: the current dataset is useful for validating the feature/label pipeline, but it is too small for credible out-of-sample model selection."
                            )
                            .foregroundStyle(.orange)

                        } else if let recommended =
                            store.labelCalibration?.recommended,
                            recommended.meetsAcceptanceBand {

                            Text(
                                "LABEL POLICY READY: \(recommended.policy.name) passed the calibration acceptance band. The policy can be locked before Phase 2C model training."
                            )
                            .foregroundStyle(.green)

                        } else if min(
                            summary.longTargetRate,
                            summary.shortTargetRate
                        ) < 0.05 {
                            Text(
                                "CAUTION: the baseline label policy is sparse. Run Label calibration before training a signal model."
                            )
                            .foregroundStyle(.orange)

                        } else {
                            Text(
                                "DATA READY: enough independent sessions exist. Run Label calibration before model training so test blocks stay untouched."
                            )
                            .foregroundStyle(.green)
                        }
                    }
                }

                Section("Label calibration") {
                    Text(
                        "Calibration uses only the earliest train + validation window. Every walk-forward test session stays reserved and is not used to rank label policies."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if store.isCalibratingLabels {
                        ProgressView()
                    }

                    Text(
                        store.labelCalibrationMessage
                    )
                    .font(.callout)
                    .textSelection(.enabled)

                    Button {
                        Task {
                            await store.calibrateLabelPolicies()
                        }
                    } label: {
                        Label(
                            "Calibrate Label Policies",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                    .disabled(
                        store.isCalibratingLabels
                        || store.isBuildingResearchDataset
                        || store.isDownloadingHistory
                        || store.isValidatingUniverse
                    )

                    if let calibration =
                        store.labelCalibration {

                        LabeledContent(
                            "Calibration sessions",
                            value: String(
                                calibration.calibrationSessionCount
                            )
                        )

                        LabeledContent(
                            "Reserved test sessions",
                            value: String(
                                calibration.reservedTestSessionCount
                            )
                        )

                        LabeledContent(
                            "Target acceptance band",
                            value:
                                "\(percent(calibration.targetBandLow))–\(percent(calibration.targetBandHigh))"
                        )

                        LabeledContent(
                            "Max ambiguity",
                            value: percent(
                                calibration.maxAmbiguousRate
                            )
                        )

                        if let recommended =
                            calibration.recommended {

                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                Text("Recommended")
                                    .font(.headline)

                                Text(
                                    recommended.policy.name
                                )
                                .font(.title3.bold())

                                LabeledContent(
                                    "Score",
                                    value: score(
                                        recommended.score
                                    )
                                )

                                LabeledContent(
                                    "LONG target",
                                    value: percent(
                                        recommended.longTargetRate
                                    )
                                )

                                LabeledContent(
                                    "SHORT target",
                                    value: percent(
                                        recommended.shortTargetRate
                                    )
                                )

                                LabeledContent(
                                    "LONG timeout",
                                    value: percent(
                                        recommended.longTimeoutRate
                                    )
                                )

                                LabeledContent(
                                    "SHORT timeout",
                                    value: percent(
                                        recommended.shortTimeoutRate
                                    )
                                )

                                LabeledContent(
                                    "Ambiguous",
                                    value: percent(
                                        recommended.ambiguousRate
                                    )
                                )

                                LabeledContent(
                                    "LONG payoff proxy",
                                    value: percent(
                                        recommended.longPayoffProxy
                                    )
                                )

                                LabeledContent(
                                    "SHORT payoff proxy",
                                    value: percent(
                                        recommended.shortPayoffProxy
                                    )
                                )

                                Text(
                                    recommended.meetsAcceptanceBand
                                    ? "ACCEPTED: both target classes are inside the calibration band and ambiguity is within limit."
                                    : "NOT YET ACCEPTED: this is the best candidate in the current grid, but at least one acceptance condition is still missed."
                                )
                                .font(.caption.bold())
                                .foregroundStyle(
                                    recommended.meetsAcceptanceBand
                                    ? Color.green
                                    : Color.orange
                                )
                            }
                            .padding(
                                .vertical,
                                4
                            )
                        }

                        DisclosureGroup(
                            "Candidate ranking (\(calibration.candidates.count))"
                        ) {
                            ForEach(
                                calibration.candidates
                            ) { candidate in
                                VStack(
                                    alignment: .leading,
                                    spacing: 6
                                ) {
                                    HStack {
                                        Text(
                                            candidate.policy.name
                                        )
                                        .font(.headline)

                                        Spacer()

                                        Text(
                                            score(
                                                candidate.score
                                            )
                                        )
                                        .monospacedDigit()
                                    }

                                    LabeledContent(
                                        "Targets L / S",
                                        value:
                                            "\(percent(candidate.longTargetRate)) / \(percent(candidate.shortTargetRate))"
                                    )

                                    LabeledContent(
                                        "Timeouts L / S",
                                        value:
                                            "\(percent(candidate.longTimeoutRate)) / \(percent(candidate.shortTimeoutRate))"
                                    )

                                    LabeledContent(
                                        "Session std L / S",
                                        value:
                                            "\(percent(candidate.longTargetRateStd)) / \(percent(candidate.shortTargetRateStd))"
                                    )

                                    LabeledContent(
                                        "Payoff proxy L / S",
                                        value:
                                            "\(percent(candidate.longPayoffProxy)) / \(percent(candidate.shortPayoffProxy))"
                                    )

                                    Text(
                                        candidate.meetsAcceptanceBand
                                        ? "accepted"
                                        : "outside acceptance band"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        candidate.meetsAcceptanceBand
                                        ? Color.green
                                        : Color.gray
                                    )
                                }
                                .padding(
                                    .vertical,
                                    6
                                )
                            }
                        }

                        Text(
                            "Payoff proxy is a label-quality diagnostic, not a trading backtest: target exits use +target, stop exits use -stop, and timeout exits use the horizon return."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Current feature set") {
                    Text(
                        "Time/session position, returns 1/5/15/30/60m, candle range, ATR(14), realized volatility(20), volume z-score(20), distance to SMA20/SMA50, distance to session high/low, and distance to causal session VWAP."
                    )
                    .foregroundStyle(.secondary)
                }

                Section("Next") {
                    Text(
                        "Phase 2C trains the first calibrated local baseline model on these folds and compares it against a no-skill baseline before any signal is allowed into the scanner."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Research Dataset")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
            .task(
                id: store.selectedAsset?.symbol
            ) {
                await store.loadLocalBars()
            }
        }
    }

    private func formatted(
        _ date: Date?
    ) -> String {
        guard let date else {
            return "None"
        }

        return formatted(date)
    }

    private func formatted(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ss"

        return formatter.string(
            from: date
        )
    }

    private func score(
        _ value: Double
    ) -> String {
        String(
            format: "%.1f",
            value
        )
    }

    private func percent(
        _ value: Double
    ) -> String {
        String(
            format: "%.2f%%",
            value * 100
        )
    }
}
