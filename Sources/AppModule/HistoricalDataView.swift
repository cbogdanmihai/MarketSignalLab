import SwiftUI

private enum BulkHistoryScope:
    String,
    CaseIterable,
    Identifiable {

    case tradeable = "Tradeable"
    case context = "Context"
    case all = "All"

    var id: String {
        rawValue
    }
}

struct HistoricalDataView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

    @State
    private var startDate =
        Calendar.current.date(
            byAdding: .day,
            value: -60,
            to: Date()
        ) ?? Date()

    @State
    private var endDate = Date()

    @State
    private var bulkScope:
        BulkHistoryScope = .tradeable

    @State
    private var skipFullyCovered = true

    private var estimatedChunks: Int {
        store.estimatedHistoricalChunks(
            startDate: startDate,
            endDate: endDate
        )
    }

    private var bulkAssets:
        [AssetConfig] {

        switch bulkScope {
        case .tradeable:
            return store.tradeableAssets

        case .context:
            return store.contextAssets

        case .all:
            return store.assets
        }
    }

    private var estimatedBulkRequests: Int {
        estimatedChunks
        * bulkAssets.count
    }

    private var estimatedBulkMinutes: Int {
        Int(
            ceil(
                Double(
                    estimatedBulkRequests
                )
                * 8.2
                / 60
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected asset") {
                    LabeledContent(
                        "Symbol",
                        value:
                            store
                                .selectedAsset?
                                .symbol
                            ?? "None"
                    )

                    LabeledContent(
                        "Provider symbol",
                        value:
                            store
                                .selectedAsset?
                                .providerSymbol
                            ?? "None"
                    )

                    LabeledContent(
                        "Interval",
                        value: "1 minute"
                    )

                    LabeledContent(
                        "Timezone",
                        value:
                            store
                                .selectedAsset?
                                .timezone
                            ?? "Unknown"
                    )
                }

                Section("Historical range") {
                    DatePicker(
                        "Start",
                        selection: $startDate,
                        displayedComponents: [
                            .date,
                            .hourAndMinute
                        ]
                    )

                    DatePicker(
                        "End",
                        selection: $endDate,
                        displayedComponents: [
                            .date,
                            .hourAndMinute
                        ]
                    )

                    LabeledContent(
                        "Requests / symbol",
                        value:
                            String(
                                estimatedChunks
                            )
                    )

                    Text(
                        "1-minute history is downloaded in 3-day chunks. One run is capped at 90 calendar days."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Section("Selected symbol") {
                    LabeledContent(
                        "Bars",
                        value:
                            String(
                                store
                                    .storageStats
                                    .count
                            )
                    )

                    LabeledContent(
                        "Earliest",
                        value:
                            formatted(
                                store
                                    .storageStats
                                    .earliest
                            )
                    )

                    LabeledContent(
                        "Latest",
                        value:
                            formatted(
                                store
                                    .storageStats
                                    .latest
                            )
                    )

                    if store.isDownloadingHistory,
                       !store.isDownloadingAllHistory {

                        ProgressView(
                            value:
                                Double(
                                    store
                                        .historyCompletedChunks
                                ),
                            total:
                                Double(
                                    max(
                                        store
                                            .historyTotalChunks,
                                        1
                                    )
                                )
                        )

                        LabeledContent(
                            "Progress",
                            value:
                                "\(store.historyCompletedChunks) / \(store.historyTotalChunks)"
                        )

                        LabeledContent(
                            "Bars received",
                            value:
                                String(
                                    store
                                        .historyBarsSaved
                                )
                        )
                    }

                    Text(
                        store.historyMessage
                    )
                    .font(.callout)
                    .textSelection(
                        .enabled
                    )

                    Button {
                        Task {
                            await store
                                .downloadHistoricalData(
                                    startDate:
                                        startDate,
                                    endDate:
                                        endDate
                                )
                        }
                    } label: {
                        Label(
                            store.isDownloadingHistory
                            ? "Downloading…"
                            : "Download Selected",
                            systemImage:
                                "arrow.down.circle"
                        )
                    }
                    .disabled(
                        store.isDownloadingHistory
                        || store
                            .isValidatingUniverse
                        || store.status.isLoading
                        || estimatedChunks == 0
                    )
                }

                Section("Bulk history") {
                    Picker(
                        "Universe",
                        selection: $bulkScope
                    ) {
                        ForEach(
                            BulkHistoryScope
                                .allCases
                        ) { scope in
                            Text(scope.rawValue)
                                .tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(
                        "Skip fully covered symbols",
                        isOn:
                            $skipFullyCovered
                    )

                    LabeledContent(
                        "Assets",
                        value:
                            String(
                                bulkAssets.count
                            )
                    )

                    LabeledContent(
                        "Maximum requests",
                        value:
                            String(
                                estimatedBulkRequests
                            )
                    )

                    LabeledContent(
                        "Approx. provider time",
                        value:
                            estimatedBulkRequests
                                == 0
                            ? "—"
                            : "~\(estimatedBulkMinutes) min"
                    )

                    Text(
                        "Bulk mode runs sequentially and uses the shared provider rate limiter. Keep Swift Playgrounds open while it is running. Existing locked label policies are preserved, but research/calibration caches are invalidated for symbols that receive new history."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    if store
                        .isDownloadingAllHistory {

                        ProgressView(
                            value:
                                Double(
                                    store
                                        .historyBatchCompletedAssets
                                ),
                            total:
                                Double(
                                    max(
                                        store
                                            .historyBatchTotalAssets,
                                        1
                                    )
                                )
                        )

                        LabeledContent(
                            "Current",
                            value:
                                store
                                    .historyBatchCurrentSymbol
                            ?? "Finishing…"
                        )

                        LabeledContent(
                            "Assets",
                            value:
                                "\(store.historyBatchCompletedAssets) / \(store.historyBatchTotalAssets)"
                        )

                        LabeledContent(
                            "Chunks",
                            value:
                                "\(store.historyCompletedChunks) / \(store.historyTotalChunks)"
                        )

                        LabeledContent(
                            "Bars received",
                            value:
                                String(
                                    store
                                        .historyBarsSaved
                                )
                        )

                        LabeledContent(
                            "Skipped",
                            value:
                                String(
                                    store
                                        .historyBatchSkippedAssets
                                )
                        )
                    }

                    Text(
                        store
                            .historyBatchMessage
                    )
                    .font(.callout)
                    .textSelection(
                        .enabled
                    )

                    Button {
                        Task {
                            await store
                                .downloadHistoricalDataForAll(
                                    assets:
                                        bulkAssets,
                                    startDate:
                                        startDate,
                                    endDate:
                                        endDate,
                                    skipFullyCovered:
                                        skipFullyCovered
                                )
                        }
                    } label: {
                        Label(
                            store
                                .isDownloadingAllHistory
                            ? "Downloading All…"
                            : "Download All",
                            systemImage:
                                "square.and.arrow.down.on.square"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        store.isDownloadingHistory
                        || bulkAssets.isEmpty
                        || estimatedChunks == 0
                    )
                }

                Section("Research pipeline") {
                    Text(
                        "History feeds the causal feature, locked-label, walk-forward and baseline-model pipeline. Data downloads never unlock or silently change an accepted label policy."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .navigationTitle(
                "Historical Data"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
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

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale.current

        formatter.timeZone =
            .current

        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ss"

        return formatter.string(
            from: date
        )
    }
}
