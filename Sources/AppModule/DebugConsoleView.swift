import SwiftUI

struct DebugConsoleView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

    @State
    private var filter = ""

    private var filteredEvents:
        [DiagnosticEvent] {

        let query =
            filter
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard !query.isEmpty else {
            return store.diagnosticEvents
        }

        return store.diagnosticEvents.filter {
            $0.level
                .lowercased()
                .contains(query)
            || $0.message
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text(
                        "\(filteredEvents.count) events"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    Button {
                        store.clearDiagnosticEvents()
                    } label: {
                        Label(
                            "Clear",
                            systemImage:
                                "trash"
                        )
                    }
                    .buttonStyle(.borderless)
                }
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .vertical,
                    8
                )

                Divider()

                ScrollViewReader { proxy in
                    List(
                        filteredEvents
                            .indices,
                        id: \.self
                    ) { index in
                        let event =
                            filteredEvents[
                                index
                            ]

                        HStack(
                            alignment: .top,
                            spacing: 10
                        ) {
                            Circle()
                                .fill(
                                    color(
                                        for:
                                            event.level
                                    )
                                )
                                .frame(
                                    width: 7,
                                    height: 7
                                )
                                .padding(
                                    .top,
                                    5
                                )

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                HStack {
                                    Text(
                                        event.level
                                            .uppercased()
                                    )
                                    .font(
                                        .caption2.bold()
                                    )

                                    Spacer()

                                    Text(
                                        event.timestamp,
                                        format:
                                            .dateTime
                                            .hour()
                                            .minute()
                                            .second()
                                    )
                                    .font(
                                        .caption2
                                            .monospacedDigit()
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }

                                Text(
                                    event.message
                                )
                                .font(
                                    .system(
                                        .caption,
                                        design:
                                            .monospaced
                                    )
                                )
                                .textSelection(
                                    .enabled
                                )
                            }
                        }
                        .id(index)
                    }
                    .listStyle(.plain)
                    .onChange(
                        of:
                            store
                                .diagnosticEvents
                                .count
                    ) { _, _ in
                        guard
                            filter.isEmpty,
                            !filteredEvents.isEmpty
                        else {
                            return
                        }

                        withAnimation {
                            proxy.scrollTo(
                                filteredEvents.count
                                    - 1,
                                anchor:
                                    .bottom
                            )
                        }
                    }
                }
            }
            .navigationTitle(
                "Debug Console"
            )
            .searchable(
                text: $filter,
                prompt:
                    "Filter messages"
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
        }
    }

    private func color(
        for level: String
    ) -> Color {
        switch level.lowercased() {
        case "error":
            return .red

        case "warning":
            return .orange

        default:
            return .green
        }
    }
}
