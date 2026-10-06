import SwiftUI

struct MarketWorkspaceView: View {
    @EnvironmentObject
    private var store: AppStore

    @State
    private var showingHistoricalData = false

    private var asset: AssetConfig? {
        store.selectedAsset
    }

    private var latest: MarketBar? {
        store.bars.last
    }

    private var previous: MarketBar? {
        guard store.bars.count >= 2 else {
            return nil
        }

        return store.bars[
            store.bars.count - 2
        ]
    }

    private var change: Double? {
        guard
            let latest,
            let previous,
            previous.close != 0
        else {
            return nil
        }

        return latest.close
            / previous.close
            - 1
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                quoteHeader

                if let asset {
                    ProfessionalChartView(
                        asset: asset,
                        bars: store.bars
                    )
                    .padding(14)
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

                    bottomStrip(
                        asset
                    )

                } else {
                    ContentUnavailableView(
                        "Select a symbol",
                        systemImage:
                            "chart.xyaxis.line",
                        description: Text(
                            "Choose a ticker from the watchlist."
                        )
                    )
                }
            }
            .padding(18)
        }
        .background(
            Color(
                uiColor:
                    .secondarySystemBackground
            )
        )
        .task(
            id: store.selectedAsset?.symbol
        ) {
            await store.loadLocalBars()
        }
        .sheet(
            isPresented:
                $showingHistoricalData
        ) {
            HistoricalDataView()
                .environmentObject(store)
        }
    }

    private var quoteHeader: some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            if let asset {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    HStack(spacing: 8) {
                        Text(asset.symbol)
                            .font(
                                .system(
                                    size: 28,
                                    weight: .bold
                                )
                            )

                        Text(
                            asset.assetClass.rawValue
                                .uppercased()
                        )
                        .font(.caption2.bold())
                        .padding(
                            .horizontal,
                            6
                        )
                        .padding(
                            .vertical,
                            3
                        )
                        .background(
                            Color.secondary
                                .opacity(0.12),
                            in:
                                Capsule()
                        )
                    }

                    Text(asset.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let latest {
                    VStack(
                        alignment: .trailing,
                        spacing: 3
                    ) {
                        Text(
                            latest.close,
                            format:
                                .number.precision(
                                    .fractionLength(2)
                                )
                        )
                        .font(
                            .system(
                                size: 26,
                                weight: .semibold,
                                design:
                                    .rounded
                            )
                        )
                        .monospacedDigit()

                        if let change {
                            Text(
                                change,
                                format:
                                    .percent.precision(
                                        .fractionLength(2)
                                    )
                            )
                            .font(.subheadline.bold())
                            .foregroundStyle(
                                change >= 0
                                ? Color.green
                                : Color.red
                            )
                        } else {
                            Text(
                                latest.timestamp,
                                format:
                                    .dateTime
                                    .month(.abbreviated)
                                    .day()
                                    .hour()
                                    .minute()
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .frame(height: 34)

                statusBadge

                Button {
                    Task {
                        await store.refreshSelected(
                            outputSize: 120
                        )
                    }
                } label: {
                    Label(
                        "Refresh",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(
                    store.status.isLoading
                    || store.isValidatingUniverse
                )

                Button {
                    showingHistoricalData = true
                } label: {
                    Label(
                        "History",
                        systemImage:
                            "clock.arrow.circlepath"
                    )
                }
                .buttonStyle(.bordered)

            } else {
                Text("Market Workspace")
                    .font(.title2.bold())
            }
        }
        .padding(14)
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

    @ViewBuilder
    private var statusBadge: some View {
        if let asset {
            let validation =
                store.validationState(
                    for: asset
                )

            HStack(spacing: 6) {
                Circle()
                    .fill(
                        statusColor(
                            validation.availability
                        )
                    )
                    .frame(
                        width: 7,
                        height: 7
                    )

                Text(
                    validation.availability
                        .rawValue
                        .replacingOccurrences(
                            of: "_",
                            with: " "
                        )
                )
                .font(.caption)
            }
            .padding(
                .horizontal,
                9
            )
            .padding(
                .vertical,
                6
            )
            .background(
                Color.secondary
                    .opacity(0.1),
                in:
                    Capsule()
            )
        }
    }

    private func bottomStrip(
        _ asset: AssetConfig
    ) -> some View {
        HStack(spacing: 10) {
            WorkspaceStat(
                title: "Stored 1m",
                value:
                    store.storageStats.count
                        .formatted(
                            .number.notation(
                                .compactName
                            )
                        )
            )

            WorkspaceStat(
                title: "Coverage",
                value:
                    coverageText
            )

            WorkspaceStat(
                title: "Research",
                value:
                    store.researchSummaryBySymbol[
                        asset.symbol
                    ] == nil
                    ? "Not built"
                    : "Ready"
            )

            WorkspaceStat(
                title: "Calibration",
                value:
                    calibrationText(
                        asset
                    )
            )

            Spacer()

            Text(store.status.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var coverageText: String {
        guard
            let earliest =
                store.storageStats.earliest,
            let latest =
                store.storageStats.latest
        else {
            return "—"
        }

        let days =
            Calendar.current
                .dateComponents(
                    [.day],
                    from: earliest,
                    to: latest
                ).day ?? 0

        return "\(max(days, 0))d"
    }

    private func calibrationText(
        _ asset: AssetConfig
    ) -> String {
        guard let recommended =
                store.labelCalibrationBySymbol[
                    asset.symbol
                ]?.recommended
        else {
            return "Pending"
        }

        return recommended
            .meetsAcceptanceBand
            ? "Accepted"
            : "Review"
    }

    private func statusColor(
        _ availability:
            ProviderAvailability
    ) -> Color {
        switch availability {
        case .available:
            return .green

        case .restricted,
             .rateLimited:
            return .orange

        case .unavailable,
             .error:
            return .red

        case .unknown,
             .checking:
            return .secondary
        }
    }
}

private struct WorkspaceStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            7
        )
        .background(
            Color(
                uiColor:
                    .tertiarySystemBackground
            ),
            in:
                RoundedRectangle(
                    cornerRadius: 8
                )
        )
    }
}
