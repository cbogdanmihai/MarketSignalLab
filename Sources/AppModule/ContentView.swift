import SwiftUI

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case chart = "Chart"
    case research = "Research"
    case data = "Data"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .chart:
            return "chart.xyaxis.line"

        case .research:
            return "flask"

        case .data:
            return "externaldrive"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject
    private var store: AppStore

    @State
    private var workspace:
        WorkspaceSection = .chart

    @State
    private var searchText = ""

    @State
    private var showingAddTicker = false

    @State
    private var showingSettings = false

    @State
    private var showingAppInfo = false

    private var filteredTradeable:
        [AssetConfig] {

        filtered(
            store.tradeableAssets
        )
    }

    private var filteredContext:
        [AssetConfig] {

        filtered(
            store.contextAssets
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar

        } detail: {
            detail
        }
        .sheet(
            isPresented:
                $showingAddTicker
        ) {
            AddTickerView()
                .environmentObject(store)
        }
        .sheet(
            isPresented:
                $showingSettings
        ) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(
            isPresented:
                $showingAppInfo
        ) {
            AppInfoView()
                .environmentObject(store)
        }
        .task {
            await store.loadLocalBars()
            await store.refreshStorageOverview()
        }
    }

    private var sidebar: some View {
        List {
            Section {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text("MARKET SIGNAL LAB")
                        .font(
                            .caption2.bold()
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    Text("Research Terminal")
                        .font(.title3.bold())
                }
                .padding(
                    .vertical,
                    4
                )
            }

            Section("Workspace") {
                ForEach(
                    WorkspaceSection.allCases
                ) { item in
                    Button {
                        workspace = item
                    } label: {
                        HStack {
                            Label(
                                item.rawValue,
                                systemImage:
                                    item.icon
                            )

                            Spacer()

                            if workspace == item {
                                Image(
                                    systemName:
                                        "circle.fill"
                                )
                                .font(
                                    .system(
                                        size: 6
                                    )
                                )
                                .foregroundStyle(
                                    .tint
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        workspace == item
                        ? Color.accentColor
                        : Color.primary
                    )
                }
            }

            Section {
                Button {
                    showingAddTicker = true
                } label: {
                    Label(
                        "Add Ticker",
                        systemImage:
                            "plus.circle.fill"
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    Color.accentColor
                )
            } header: {
                HStack {
                    Text("Watchlist")

                    Spacer()

                    Text(
                        "\(store.tradeableAssets.count)"
                    )
                }
            }

            Section("Tradeable") {
                ForEach(
                    filteredTradeable
                ) { asset in
                    watchlistRow(
                        asset
                    )
                }
            }

            if !filteredContext.isEmpty {
                Section("Context") {
                    ForEach(
                        filteredContext
                    ) { asset in
                        watchlistRow(
                            asset
                        )
                    }
                }
            }

            Section("System") {
                Button {
                    showingAppInfo = true
                } label: {
                    Label(
                        "App Info",
                        systemImage:
                            "info.circle"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showingSettings = true
                } label: {
                    Label(
                        "Settings",
                        systemImage:
                            "gearshape"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await store.validateUniverse()
                    }
                } label: {
                    HStack {
                        Label(
                            "Validate Universe",
                            systemImage:
                                "checkmark.shield"
                        )

                        Spacer()

                        if store.isValidatingUniverse {
                            ProgressView()
                                .controlSize(
                                    .small
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(
                    store.isValidatingUniverse
                )
            }
        }
        .navigationTitle("MarketSignalLab")
        .searchable(
            text: $searchText,
            prompt:
                "Search watchlist"
        )
        .toolbar {
            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Button {
                    showingAddTicker = true
                } label: {
                    Image(
                        systemName: "plus"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch workspace {
        case .chart:
            MarketWorkspaceView()
                .environmentObject(store)

        case .research:
            ResearchHubView()
                .environmentObject(store)

        case .data:
            DataWorkspaceView()
                .environmentObject(store)
        }
    }

    private func watchlistRow(
        _ asset: AssetConfig
    ) -> some View {
        Button {
            store.selectedAsset = asset

            Task {
                await store.loadLocalBars()
            }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(
                        statusColor(
                            store
                                .validationState(
                                    for: asset
                                )
                                .availability
                        )
                    )
                    .frame(
                        width: 7,
                        height: 7
                    )

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {
                    HStack(spacing: 5) {
                        Text(asset.symbol)
                            .font(
                                .subheadline
                                    .weight(
                                        store
                                            .selectedAsset?
                                            .symbol
                                            == asset.symbol
                                        ? .bold
                                        : .semibold
                                    )
                            )

                        if store.isCustomAsset(
                            asset
                        ) {
                            Text("CUSTOM")
                                .font(
                                    .system(
                                        size: 7,
                                        weight: .bold
                                    )
                                )
                                .padding(
                                    .horizontal,
                                    4
                                )
                                .padding(
                                    .vertical,
                                    2
                                )
                                .background(
                                    Color.accentColor
                                        .opacity(0.15),
                                    in:
                                        Capsule()
                                )
                        }
                    }

                    Text(
                        asset.displayName
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }

                Spacer()

                let stats =
                    store.storageOverview[
                        asset.symbol
                    ] ?? .empty

                if let latest =
                    stats.latestClose {

                    VStack(
                        alignment: .trailing,
                        spacing: 1
                    ) {
                        Text(
                            latest,
                            format:
                                .number.precision(
                                    .fractionLength(2)
                                )
                        )
                        .font(
                            .caption
                                .weight(.semibold)
                                .monospacedDigit()
                        )

                        if let change =
                            stats.latestChangePct {

                            Text(
                                change,
                                format:
                                    .percent.precision(
                                        .fractionLength(2)
                                    )
                            )
                            .font(
                                .caption2
                                    .monospacedDigit()
                            )
                            .foregroundStyle(
                                change >= 0
                                ? Color.green
                                : Color.red
                            )

                        } else {
                            Text(
                                stats.count.formatted(
                                    .number.notation(
                                        .compactName
                                    )
                                )
                                + " bars"
                            )
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }

                } else if stats.count > 0 {
                    Text(
                        stats.count.formatted(
                            .number.notation(
                                .compactName
                            )
                        )
                        + " bars"
                    )
                    .font(
                        .caption2
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(
            store.selectedAsset?.symbol
                == asset.symbol
            ? Color.accentColor
                .opacity(0.10)
            : Color.clear
        )
        .contextMenu {
            Button {
                store.selectedAsset = asset
                workspace = .chart

                Task {
                    await store.loadLocalBars()
                }
            } label: {
                Label(
                    "Open Chart",
                    systemImage:
                        "chart.xyaxis.line"
                )
            }

            Button {
                store.selectedAsset = asset
                workspace = .research

                Task {
                    await store.loadLocalBars()
                }
            } label: {
                Label(
                    "Open Research",
                    systemImage:
                        "flask"
                )
            }

            if store.isCustomAsset(
                asset
            ) {
                Divider()

                Button(
                    role: .destructive
                ) {
                    store.removeCustomAsset(
                        asset
                    )
                } label: {
                    Label(
                        "Remove Ticker",
                        systemImage:
                            "trash"
                    )
                }
            }
        }
    }

    private func filtered(
        _ assets: [AssetConfig]
    ) -> [AssetConfig] {
        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard !query.isEmpty else {
            return assets
        }

        return assets.filter {
            $0.symbol
                .lowercased()
                .contains(query)
            || $0.displayName
                .lowercased()
                .contains(query)
        }
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

        case .checking:
            return .blue

        case .unknown:
            return .secondary
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Twelve Data") {
                    SecureField(
                        "API key",
                        text: $store.apiKey
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .autocorrectionDisabled()

                    Text(
                        "The API key is stored in the iPad Keychain and is never included in diagnostics or the GitHub repository."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Universe") {
                    LabeledContent(
                        "Built-in + custom",
                        value:
                            String(
                                store.assets.count
                            )
                    )

                    LabeledContent(
                        "Custom tickers",
                        value:
                            String(
                                store.customAssets.count
                            )
                    )
                }

                Section {
                    Button("Save API key") {
                        store.saveAPIKey()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
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
        }
    }
}
