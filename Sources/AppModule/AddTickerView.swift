import SwiftUI
import UIKit

private struct TouchTickerKeyboard: View {
    @Binding
    var text: String

    private let rows: [[String]] = [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M","/","-","."]
    ]

    var body: some View {
        VStack(spacing: 7) {
            ForEach(
                rows.indices,
                id: \.self
            ) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(
                        rows[rowIndex],
                        id: \.self
                    ) { key in
                        Button(key) {
                            append(key)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(
                            minWidth: 34
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    if !text.isEmpty {
                        text.removeLast()
                    }
                } label: {
                    Label(
                        "Delete",
                        systemImage:
                            "delete.left"
                    )
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    text = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(
                    text.isEmpty
                    ? "Enter ticker"
                    : text
                )
                .font(
                    .headline.monospaced()
                )
                .foregroundStyle(
                    text.isEmpty
                    ? .secondary
                    : .primary
                )
            }
        }
        .padding(12)
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

    private func append(
        _ key: String
    ) {
        guard text.count < 24 else {
            return
        }

        text.append(key)
    }
}

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

    @State
    private var showTouchInput = false

    private var normalizedSymbol: String {
        symbol
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    symbolCard

                    providerCard

                    addButton
                }
                .padding(20)
                .frame(
                    maxWidth: 760,
                    alignment: .top
                )
                .frame(
                    maxWidth: .infinity
                )
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
            }
        }
    }

    private var symbolCard: some View {
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
            .onChange(
                of: symbol
            ) { _, newValue in
                let upper =
                    newValue.uppercased()

                if upper != newValue {
                    symbol = upper
                }
            }

            HStack(spacing: 8) {
                Button {
                    if let clipboard =
                        UIPasteboard
                            .general
                            .string {

                        symbol =
                            clipboard
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                                .uppercased()
                    }
                } label: {
                    Label(
                        "Paste",
                        systemImage:
                            "doc.on.clipboard"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    focusedField = nil
                    showTouchInput.toggle()
                } label: {
                    Label(
                        showTouchInput
                        ? "Hide Touch Input"
                        : "Touch Input",
                        systemImage:
                            "keyboard"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !symbol.isEmpty {
                    Button("Clear") {
                        symbol = ""
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Spacer()
            }

            if showTouchInput {
                TouchTickerKeyboard(
                    text: $symbol
                )
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

            if focusedField == .symbol {
                Text(
                    "If Swift Playgrounds does not present the iPad software keyboard, use Touch Input or Paste above."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
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
    }

    private var providerCard: some View {
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
    }

    private var addButton: some View {
        Button {
            focusedField = nil

            Task {
                await store
                    .addCustomAsset(
                        symbol:
                            normalizedSymbol,
                        displayName:
                            displayName,
                        assetClass:
                            assetClass
                    )

                if store
                    .selectedAsset?
                    .symbol
                    == normalizedSymbol {

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
            normalizedSymbol.isEmpty
            || store
                .isAddingCustomAsset
        )
    }
}
