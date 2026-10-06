import SwiftUI

enum TerminalDensity: String, CaseIterable, Identifiable {
    case ultraCompact
    case compact
    case dense
    case standard
    case large

    static let storageKey =
        "MarketSignalLab.TerminalDensity"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .ultraCompact:
            return "Ultra Compact"
        case .compact:
            return "Compact"
        case .dense:
            return "Dense"
        case .standard:
            return "Standard"
        case .large:
            return "Large"
        }
    }

    var percentage: Int {
        switch self {
        case .ultraCompact:
            return 70
        case .compact:
            return 80
        case .dense:
            return 90
        case .standard:
            return 100
        case .large:
            return 115
        }
    }

    var layoutScale: CGFloat {
        CGFloat(percentage) / 100
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .ultraCompact:
            return .xSmall
        case .compact:
            return .xSmall
        case .dense:
            return .small
        case .standard:
            return .medium
        case .large:
            return .large
        }
    }

    var controlSize: ControlSize {
        switch self {
        case .ultraCompact,
             .compact:
            return .mini
        case .dense:
            return .small
        case .standard,
             .large:
            return .regular
        }
    }

    func smaller() -> TerminalDensity {
        let values = Self.allCases

        guard let index =
                values.firstIndex(of: self),
              index > values.startIndex
        else {
            return self
        }

        return values[
            values.index(before: index)
        ]
    }

    func larger() -> TerminalDensity {
        let values = Self.allCases

        guard let index =
                values.firstIndex(of: self),
              index < values.index(
                before: values.endIndex
              )
        else {
            return self
        }

        return values[
            values.index(after: index)
        ]
    }
}

private struct TerminalDensityScaleKey:
    EnvironmentKey {

    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var terminalDensityScale: CGFloat {
        get {
            self[
                TerminalDensityScaleKey.self
            ]
        }

        set {
            self[
                TerminalDensityScaleKey.self
            ] = newValue
        }
    }
}

struct TerminalDensityControl: View {
    @AppStorage(
        TerminalDensity.storageKey
    )
    private var densityRaw =
        TerminalDensity.standard.rawValue

    private var density: TerminalDensity {
        TerminalDensity(
            rawValue: densityRaw
        ) ?? .standard
    }

    var body: some View {
        HStack(spacing: 3) {
            Button {
                densityRaw =
                    density.smaller().rawValue
            } label: {
                Image(
                    systemName: "minus"
                )
                .frame(
                    width: 18,
                    height: 18
                )
            }
            .buttonStyle(.plain)
            .disabled(
                density == .compact
            )
            .accessibilityLabel(
                "Make interface smaller"
            )

            Menu {
                ForEach(
                    TerminalDensity.allCases
                ) { option in
                    Button {
                        densityRaw =
                            option.rawValue
                    } label: {
                        if option == density {
                            Label(
                                "\(option.title) · \(option.percentage)%",
                                systemImage:
                                    "checkmark"
                            )
                        } else {
                            Text(
                                "\(option.title) · \(option.percentage)%"
                            )
                        }
                    }
                }
            } label: {
                Text(
                    "Aa \(density.percentage)%"
                )
                .font(
                    .caption
                        .weight(.semibold)
                )
                .monospacedDigit()
                .frame(
                    minWidth: 58
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Interface size"
            )

            Button {
                densityRaw =
                    density.larger().rawValue
            } label: {
                Image(
                    systemName: "plus"
                )
                .frame(
                    width: 18,
                    height: 18
                )
            }
            .buttonStyle(.plain)
            .disabled(
                density == .large
            )
            .accessibilityLabel(
                "Make interface larger"
            )
        }
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            6
        )
        .background(
            .thinMaterial,
            in:
                Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    Color.secondary
                        .opacity(0.18),
                    lineWidth: 1
                )
        )
    }
}
