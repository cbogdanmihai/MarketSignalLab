import SwiftUI

struct ResearchDatasetView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

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
                        || store.storageStats.count < 300
                    )
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
                        Text(
                            "Build the dataset first. With enough rows, the app creates three expanding walk-forward folds with a 90-minute purge before validation/test boundaries to reduce label leakage."
                        )
                        .foregroundStyle(.secondary)

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
                        dismiss()
                    }
                }
            }
            .task {
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

    private func percent(
        _ value: Double
    ) -> String {
        String(
            format: "%.2f%%",
            value * 100
        )
    }
}
