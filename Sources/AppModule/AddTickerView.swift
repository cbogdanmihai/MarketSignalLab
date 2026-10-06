import SwiftUI

struct AddTickerView: View {
    private enum Field {
        case symbol
        case displayName
    }

    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

    @FocusState
    private var focusedField: Field?

    @State
    private var symbol = ""

    @State
    private var displayName = ""

    @State
    private var assetClass: AssetClass = .equity

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Text("Add symbol")
                            .font(.headline)

                        TextField(
                            "Ticker or provider symbol",
                            text: $symbol
                        )
                        .textFieldStyle(
                            .roundedBorder
                        )
                        .textInputAutocapitalization(
                            .characters
                        )
                        .autocorrectionDisabled()
                        .keyboardType(
                            .asciiCapable
                        )
                        .submitLabel(.next)
                        .focused(
                            $focusedField,
                            equals: .symbol
                        )
                        .onSubmit {
                            focusedField =
                                .displayName
                        }

                        TextField(
                            "Display name (optional)",
                            text: $displayName
                        )
                        .textFieldStyle(
                            .roundedBorder
                        )
                        .submitLabel(.done)
                        .focused(
                            $focusedField,
                            equals:
                                .displayName
                        )
                        .onSubmit {
                            focusedField = nil
                        }

                        Picker(
                            "Asset type",
                            selection:
                                $assetClass
                        ) {
                            Text("Equity")
                                .tag(
                                    AssetClass.equity
                                )

                            Text("ETF")
                                .tag(
                                    AssetClass.etf
                                )

                            Text("Crypto")
                                .tag(
                                    AssetClass.crypto
                                )

                            Text("Index")
                                .tag(
                                    AssetClass.index
                                )

                            Text(
                                "Commodity proxy"
                            )
                            .tag(
                                AssetClass
                                    .commodityProxy
                            )
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(16)
                    .background(
                        Color(
                            uiColor:
                                .secondarySystemBackground
                        ),
                        in:
                            RoundedRectangle(
                                cornerRadius: 12
                            )
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Text("Provider")
                            .font(.headline)

                        Text(
                            "New symbols are checked against Twelve Data when an API key is available. Custom symbols are stored locally on this iPad and merged with the built-in universe."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        if store
                            .isAddingCustomAsset {

                            ProgressView(
                                "Checking symbol…"
                            )
                        }

                        if !store
                            .customAssetMessage
                            .isEmpty {

                            Text(
                                store
                                    .customAssetMessage
                            )
                            .font(.callout)
                            .foregroundStyle(
                                .secondary
                            )
                            .textSelection(
                                .enabled
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        Color(
                            uiColor:
                                .secondarySystemBackground
                        ),
                        in:
                            RoundedRectangle(
                                cornerRadius: 12
                            )
                    )

                    Button {
                        focusedField = nil

                        Task {
                            await store
                                .addCustomAsset(
                                    symbol: symbol,
                                    displayName:
                                        displayName,
                                    assetClass:
                                        assetClass
                                )

                            let normalized =
                                symbol
                                    .trimmingCharacters(
                                        in:
                                            .whitespacesAndNewlines
                                    )
                                    .uppercased()

                            if store
                                .selectedAsset?
                                .symbol
                                == normalized {

                                dismiss()
                            }
                        }
                    } label: {
                        Label(
                            "Add to Watchlist",
                            systemImage:
                                "plus.circle.fill"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        symbol
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        || store
                            .isAddingCustomAsset
                    )
                }
                .padding(20)
            }
            .navigationTitle("Add Ticker")
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(
                    placement: .keyboard
                ) {
                    Spacer()

                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                DispatchQueue.main
                    .asyncAfter(
                        deadline:
                            .now() + 0.2
                    ) {
                        focusedField =
                            .symbol
                    }
            }
        }
    }
}
