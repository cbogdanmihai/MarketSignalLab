import SwiftUI

struct AddTickerView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

    @State
    private var symbol = ""

    @State
    private var displayName = ""

    @State
    private var assetClass: AssetClass = .equity

    var body: some View {
        NavigationStack {
            Form {
                Section("Add symbol") {
                    TextField(
                        "Ticker or provider symbol",
                        text: $symbol
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                    TextField(
                        "Display name (optional)",
                        text: $displayName
                    )

                    Picker(
                        "Asset type",
                        selection: $assetClass
                    ) {
                        Text("Equity")
                            .tag(AssetClass.equity)

                        Text("ETF")
                            .tag(AssetClass.etf)

                        Text("Crypto")
                            .tag(AssetClass.crypto)

                        Text("Index")
                            .tag(AssetClass.index)

                        Text("Commodity proxy")
                            .tag(AssetClass.commodityProxy)
                    }
                }

                Section("Provider") {
                    Text(
                        "New symbols are checked against Twelve Data when an API key is available. Custom symbols are stored locally on this iPad and merged with the built-in universe."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if store.isAddingCustomAsset {
                        ProgressView(
                            "Checking symbol…"
                        )
                    }

                    if !store.customAssetMessage.isEmpty {
                        Text(store.customAssetMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button {
                        Task {
                            await store.addCustomAsset(
                                symbol: symbol,
                                displayName: displayName,
                                assetClass: assetClass
                            )

                            if store.selectedAsset?.symbol
                                == symbol
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .uppercased() {

                                dismiss()
                            }
                        }
                    } label: {
                        Label(
                            "Add to Watchlist",
                            systemImage: "plus.circle.fill"
                        )
                    }
                    .disabled(
                        symbol.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                        || store.isAddingCustomAsset
                    )
                }
            }
            .navigationTitle("Add Ticker")
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
