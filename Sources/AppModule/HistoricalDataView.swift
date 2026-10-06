import SwiftUI

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

    private var estimatedChunks: Int {
        store.estimatedHistoricalChunks(
            startDate: startDate,
            endDate: endDate
        )
    }

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
                        "Provider symbol",
                        value: store.selectedAsset?.providerSymbol
                            ?? "None"
                    )

                    LabeledContent(
                        "Interval",
                        value: "1 minute"
                    )

                    LabeledContent(
                        "Timezone",
                        value: store.selectedAsset?.timezone
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
                        "Estimated API requests",
                        value: String(
                            estimatedChunks
                        )
                    )

                    Text(
                        "The default research range is 60 calendar days. Phase 2A uses 3-day chunks for 1-minute data, keeping each response below Twelve Data's 5,000-point limit even for 24/7 crypto. One import is capped at 90 days."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Local storage") {
                    LabeledContent(
                        "Bars",
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

                    Text(
                        "Bars are deduplicated and stored in monthly partitions under Application Support."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Download") {
                    if store.isDownloadingHistory {
                        ProgressView(
                            value: Double(
                                store.historyCompletedChunks
                            ),
                            total: Double(
                                max(
                                    store.historyTotalChunks,
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
                            value: String(
                                store.historyBarsSaved
                            )
                        )
                    }

                    Text(store.historyMessage)
                        .font(.callout)
                        .textSelection(.enabled)

                    Button {
                        Task {
                            await store.downloadHistoricalData(
                                startDate: startDate,
                                endDate: endDate
                            )
                        }
                    } label: {
                        Label(
                            store.isDownloadingHistory
                                ? "Downloading…"
                                : "Download Historical Data",
                            systemImage:
                                "arrow.down.circle"
                        )
                    }
                    .disabled(
                        store.isDownloadingHistory
                        || store.isValidatingUniverse
                        || store.status.isLoading
                        || estimatedChunks == 0
                    )
                }

                Section("Research pipeline") {
                    Text(
                        "This is the ingestion layer for Phase 2. The next step uses the stored canonical bars to build features, labels and walk-forward datasets locally on the iPad."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Historical Data")
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

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ss"

        return formatter.string(
            from: date
        )
    }
}
