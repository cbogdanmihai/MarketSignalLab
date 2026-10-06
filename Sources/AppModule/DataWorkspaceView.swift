import SwiftUI

struct DataWorkspaceView: View {
    @EnvironmentObject
    private var store: AppStore

    @Environment(\.terminalDensityScale)
    private var densityScale

    @State
    private var showingHistoricalData = false

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text("Data Center")
                            .font(.title.bold())

                        Text(
                            "Provider health, local history coverage and ingestion controls"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingHistoricalData = true
                    } label: {
                        Label(
                            "Historical Downloader",
                            systemImage:
                                "arrow.down.to.line"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task {
                            await store.validateUniverse()
                        }
                    } label: {
                        Label(
                            "Validate Universe",
                            systemImage:
                                "checkmark.shield"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        store.isValidatingUniverse
                    )

                    TerminalDensityControl()
                }

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 170
                            ),
                            spacing: 10
                        )
                    ],
                    spacing: 10
                ) {
                    DataMetric(
                        title: "Available",
                        value:
                            String(
                                store.availableCount
                            ),
                        detail:
                            "Provider symbols"
                    )

                    DataMetric(
                        title: "Restricted",
                        value:
                            String(
                                store.restrictedCount
                            ),
                        detail:
                            "Account limitations"
                    )

                    DataMetric(
                        title: "Unavailable",
                        value:
                            String(
                                store.unavailableCount
                            ),
                        detail:
                            "Invalid / no feed"
                    )

                    DataMetric(
                        title: "Rate limited",
                        value:
                            String(
                                store.rateLimitedCount
                            ),
                        detail:
                            "Temporary"
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text("Local History")
                        .font(.headline)

                    Text(
                        "Bars are stored locally in monthly partitions and deduplicated by canonical bar ID."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(
                        store.assets
                    ) { asset in
                        let stats =
                            store.storageOverview[
                                asset.symbol
                            ]
                            ?? .empty

                        HStack {
                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text(asset.symbol)
                                    .font(.headline)

                                Text(
                                    asset.displayName
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }

                            Spacer()

                            Text(
                                stats.count.formatted(
                                    .number.notation(
                                        .compactName
                                    )
                                )
                            )
                            .monospacedDigit()
                            .frame(
                                width: 80,
                                alignment: .trailing
                            )

                            Text(
                                coverage(
                                    stats
                                )
                            )
                            .foregroundStyle(.secondary)
                            .frame(
                                width: 120,
                                alignment: .trailing
                            )

                            Button("Open") {
                                store.selectedAsset =
                                    asset

                                Task {
                                    await store.loadLocalBars()
                                    showingHistoricalData =
                                        true
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(
                            .vertical,
                            7
                        )

                        Divider()
                    }
                }
                .padding(
                    16 * densityScale
                )
                .background(
                    Color(
                        uiColor:
                            .tertiarySystemBackground
                    ),
                    in:
                        RoundedRectangle(
                            cornerRadius: 12
                        )
                )
            }
            .padding(
                20 * densityScale
            )
        }
        .background(
            Color(
                uiColor:
                    .secondarySystemBackground
            )
        )
        .task {
            await store.refreshStorageOverview()
        }
        .sheet(
            isPresented:
                $showingHistoricalData
        ) {
            HistoricalDataView()
                .environmentObject(store)
        }
    }

    private func coverage(
        _ stats: BarStorageStats
    ) -> String {
        guard
            let start = stats.earliest,
            let end = stats.latest
        else {
            return "No data"
        }

        let days =
            Calendar.current
                .dateComponents(
                    [.day],
                    from: start,
                    to: end
                ).day ?? 0

        return "~\(max(days, 0))d"
    }
}

private struct DataMetric: View {
    @Environment(\.terminalDensityScale)
    private var densityScale

    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title.bold())
                .monospacedDigit()

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight:
                90 * densityScale,
            alignment: .leading
        )
        .padding(
            12 * densityScale
        )
        .background(
            Color(
                uiColor:
                    .tertiarySystemBackground
            ),
            in:
                RoundedRectangle(
                    cornerRadius: 10
                )
        )
    }
}
