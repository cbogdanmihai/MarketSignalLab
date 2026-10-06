import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    @State
    private var showingAppInfo = false

    @State
    private var showingHistoricalData = false

    var body: some View {
        NavigationSplitView {
            List(
                selection: Binding(
                    get: {
                        store.selectedAsset
                    },
                    set: { newValue in
                        store.selectedAsset = newValue

                        Task {
                            await store.loadLocalBars()
                        }
                    }
                )
            ) {
                Section("Provider") {
                    Button {
                        showingAppInfo = true
                    } label: {
                        Label(
                            "App Info",
                            systemImage: "info.circle"
                        )
                    }

                    Button {
                        showingHistoricalData = true
                    } label: {
                        Label(
                            "Historical Data",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }

                    Button {
                        Task {
                            await store.validateUniverse()
                        }
                    } label: {
                        HStack {
                            Label(
                                "Validate Universe",
                                systemImage: "checkmark.shield"
                            )

                            Spacer()

                            if store.isValidatingUniverse {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(store.isValidatingUniverse)

                    Button {
                        Task {
                            await store.validateUniverse(force: true)
                        }
                    } label: {
                        Label(
                            "Force Revalidate",
                            systemImage: "arrow.clockwise.circle"
                        )
                    }
                    .disabled(store.isValidatingUniverse)

                    if store.isValidatingUniverse {
                        ProgressView(
                            value: Double(store.validationProgress),
                            total: Double(max(store.assets.count, 1))
                        )

                        Text(
                            "\(store.validationProgress) / \(store.assets.count)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if !store.validations.isEmpty {
                        HStack {
                            Text("Available")
                            Spacer()
                            Text("\(store.availableCount)")
                                .foregroundStyle(.green)
                        }

                        HStack {
                            Text("Restricted")
                            Spacer()
                            Text("\(store.restrictedCount)")
                                .foregroundStyle(.orange)
                        }

                        HStack {
                            Text("Unavailable")
                            Spacer()
                            Text("\(store.unavailableCount)")
                                .foregroundStyle(.red)
                        }

                        HStack {
                            Text("Rate limited")
                            Spacer()
                            Text("\(store.rateLimitedCount)")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Tradeable") {
                    ForEach(store.tradeableAssets) { asset in
                        AssetRow(asset: asset)
                            .tag(asset)
                    }
                }

                Section("Context") {
                    ForEach(store.contextAssets) { asset in
                        AssetRow(asset: asset)
                            .tag(asset)
                    }
                }
            }
            .navigationTitle("Universe")

        } detail: {
            if let asset = store.selectedAsset {
                AssetDashboard(asset: asset)
            } else {
                ContentUnavailableView(
                    "No asset selected",
                    systemImage: "chart.xyaxis.line"
                )
            }
        }
        .task {
            await store.loadLocalBars()
        }
        .sheet(
            isPresented: $showingAppInfo
        ) {
            AppInfoView()
                .environmentObject(store)
        }
        .sheet(
            isPresented: $showingHistoricalData
        ) {
            HistoricalDataView()
                .environmentObject(store)
        }
    }
}


// MARK: - Asset Row

private struct AssetRow: View {
    @EnvironmentObject
    private var store: AppStore

    let asset: AssetConfig

    private var validation: AssetValidationState {
        store.validationState(for: asset)
    }

    var body: some View {
        HStack(spacing: 10) {
            statusIcon

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(asset.symbol)
                    .font(.headline)

                Text(asset.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch validation.availability {
        case .unknown:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)

        case .checking:
            ProgressView()
                .controlSize(.small)

        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .restricted:
            Image(systemName: "lock.circle.fill")
                .foregroundStyle(.orange)

        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)

        case .rateLimited:
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        }
    }
}


// MARK: - Asset Dashboard

private struct AssetDashboard: View {
    @EnvironmentObject
    private var store: AppStore

    @State
    private var showingSettings = false

    let asset: AssetConfig

    private var validation: AssetValidationState {
        store.validationState(for: asset)
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                HStack(
                    alignment: .center,
                    spacing: 20
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(asset.symbol)
                            .font(
                                .system(
                                    size: 42,
                                    weight: .bold
                                )
                            )

                        Text(asset.displayName)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let last = store.bars.last {
                        VStack(
                            alignment: .trailing,
                            spacing: 4
                        ) {
                            Text(
                                last.close,
                                format: .number.precision(
                                    .fractionLength(2)
                                )
                            )
                            .font(.title.bold())

                            Text("latest stored close")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Label(
                            "Settings",
                            systemImage: "gearshape"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                GroupBox("Phase 1 status") {
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        LabeledContent(
                            "Role",
                            value: asset.role.rawValue
                        )

                        LabeledContent(
                            "Model group",
                            value: asset.modelGroup
                        )

                        LabeledContent(
                            "Timezone",
                            value: asset.timezone
                        )

                        LabeledContent(
                            "Provider symbol",
                            value: asset.providerSymbol
                        )

                        LabeledContent(
                            "Provider status",
                            value: validation.availability.rawValue
                        )

                        LabeledContent(
                            "Stored 1m bars",
                            value: String(store.bars.count)
                        )

                        if validation.availability != .unknown {
                            Text(validation.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }

                if store.bars.count >= 2 {
                    Chart(
                        Array(store.bars.suffix(120))
                    ) { bar in
                        LineMark(
                            x: .value(
                                "Time",
                                bar.timestamp
                            ),
                            y: .value(
                                "Close",
                                bar.close
                            )
                        )
                    }
                    .frame(height: 300)

                } else {
                    ContentUnavailableView(
                        "No local market data",
                        systemImage: "externaldrive",
                        description: Text(
                            "Validate the universe, then fetch this asset if it is available."
                        )
                    )
                    .frame(height: 260)
                }

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await store.refreshSelected(
                                outputSize: 120
                            )
                        }
                    } label: {
                        Label(
                            "Fetch 120 × 1m bars",
                            systemImage: "arrow.down.circle"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        store.status.isLoading
                        || store.isValidatingUniverse
                        || validation.availability == .restricted
                        || validation.availability == .unavailable
                    )

                    Button {
                        Task {
                            await store.loadLocalBars()
                        }
                    } label: {
                        Label(
                            "Load local",
                            systemImage: "internaldrive"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await store.validateUniverse()
                        }
                    } label: {
                        Label(
                            "Validate Universe",
                            systemImage: "checkmark.shield"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isValidatingUniverse)
                }

                GroupBox("Collaboration") {
                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        Text(
                            "Create a JSON snapshot with provider status, local bar counts and recent diagnostic events. The API key is never included."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button {
                                store.prepareDiagnostics()
                            } label: {
                                Label(
                                    "Prepare Diagnostics",
                                    systemImage: "doc.badge.gearshape"
                                )
                            }
                            .buttonStyle(.bordered)

                            if let url = store.diagnosticsURL {
                                ShareLink(item: url) {
                                    Label(
                                        "Share Diagnostics",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }

                GroupBox("System") {
                    HStack(spacing: 10) {
                        if store.status.isLoading
                            || store.isValidatingUniverse {
                            ProgressView()
                        }

                        Text(store.status.message)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }

                GroupBox("Phase 2") {
                    Text(
                        """
                        Historical ingestion is now active. Use Historical Data to build the local 1-minute research store; feature engineering and labels come next.
                        """
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }
            }
            .padding(24)
        }
        .sheet(
            isPresented: $showingSettings
        ) {
            SettingsView()
                .environmentObject(store)
        }
    }
}


// MARK: - Settings

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
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Text(
                        "The API key is stored securely in the iPad Keychain and is not stored inside the project or diagnostics export."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Button("Save API key") {
                        store.saveAPIKey()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Data Settings")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
