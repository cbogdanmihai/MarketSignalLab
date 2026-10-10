import SwiftUI

struct HistoryRunMonitorView: View {
    @EnvironmentObject
    private var store: AppStore

    var body: some View {
        TimelineView(
            .periodic(
                from: .now,
                by: 1
            )
        ) { context in
            if let started =
                store.historyRunStartedAt {

                let elapsed =
                    max(
                        0,
                        context.date
                            .timeIntervalSince(
                                started
                            )
                    )

                let requestElapsed =
                    store
                        .historyCurrentRequestStartedAt
                        .map {
                            max(
                                0,
                                context.date
                                    .timeIntervalSince(
                                        $0
                                    )
                            )
                        }

                let lastProgressAgo =
                    store
                        .historyLastProgressAt
                        .map {
                            max(
                                0,
                                context.date
                                    .timeIntervalSince(
                                        $0
                                    )
                            )
                        }

                let remaining =
                    store
                        .historyRunDeadline
                        .map {
                            $0.timeIntervalSince(
                                context.date
                            )
                        }

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    HStack(spacing: 18) {
                        monitorMetric(
                            "Elapsed",
                            value:
                                durationText(
                                    elapsed
                                )
                        )

                        monitorMetric(
                            "Current request",
                            value:
                                requestElapsed
                                .map(
                                    durationText
                                )
                                ?? "—"
                        )

                        monitorMetric(
                            "Last progress",
                            value:
                                lastProgressAgo
                                .map {
                                    "\(durationText($0)) ago"
                                }
                                ?? "—"
                        )

                        monitorMetric(
                            "Watchdog",
                            value:
                                remaining
                                .map {
                                    $0 > 0
                                    ? durationText($0)
                                    : "EXPIRED"
                                }
                                ?? "—"
                        )

                        Spacer()

                        Button(
                            role: .destructive
                        ) {
                            store
                                .cancelHistoricalDownload()
                        } label: {
                            Label(
                                store
                                    .historyCancellationRequested
                                ? "Cancelling…"
                                : "Cancel",
                                systemImage:
                                    "xmark.circle.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            store
                                .historyCancellationRequested
                        )
                    }

                    if !store
                        .historyCurrentRequestDescription
                        .isEmpty {

                        Text(
                            store
                                .historyCurrentRequestDescription
                        )
                        .font(
                            .caption.monospaced()
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .textSelection(
                            .enabled
                        )
                    }

                    Text(
                        store.historyWatchdogMessage
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

            } else if let lastDuration =
                store.historyLastRunDuration {

                HStack {
                    Label(
                        "Last history run: \(durationText(lastDuration))",
                        systemImage:
                            "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    Text(
                        store.historyWatchdogMessage
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func monitorMetric(
        _ title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )

            Text(value)
                .font(
                    .caption.bold()
                        .monospacedDigit()
                )
        }
    }

    private func durationText(
        _ interval: TimeInterval
    ) -> String {
        let total =
            max(
                0,
                Int(interval.rounded())
            )

        let hours =
            total / 3600

        let minutes =
            (total % 3600) / 60

        let seconds =
            total % 60

        if hours > 0 {
            return String(
                format:
                    "%02d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format:
                "%02d:%02d",
            minutes,
            seconds
        )
    }
}

struct BaselineRunMonitorView: View {
    @EnvironmentObject
    private var store: AppStore

    var body: some View {
        TimelineView(
            .periodic(
                from: .now,
                by: 1
            )
        ) { context in
            if let started =
                store.baselineTrainingStartedAt {

                let elapsed =
                    max(
                        0,
                        context.date
                            .timeIntervalSince(
                                started
                            )
                    )

                let remaining =
                    store
                        .baselineTrainingDeadline
                        .map {
                            $0.timeIntervalSince(
                                context.date
                            )
                        }

                HStack(spacing: 18) {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text("Elapsed")
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )

                        Text(
                            durationText(
                                elapsed
                            )
                        )
                        .font(
                            .caption.bold()
                                .monospacedDigit()
                        )
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text("5-min watchdog")
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )

                        Text(
                            remaining
                            .map {
                                $0 > 0
                                ? durationText($0)
                                : "EXPIRED"
                            }
                            ?? "—"
                        )
                        .font(
                            .caption.bold()
                                .monospacedDigit()
                        )
                    }

                    Spacer()

                    Button(
                        role: .destructive
                    ) {
                        store
                            .cancelBaselineTraining()
                    } label: {
                        Label(
                            store
                                .baselineCancellationRequested
                            ? "Cancelling…"
                            : "Cancel Training",
                            systemImage:
                                "xmark.circle.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        store
                            .baselineCancellationRequested
                    )
                }

            } else if let duration =
                store.baselineLastRunDuration {

                Label(
                    "Last baseline run: \(durationText(duration))",
                    systemImage:
                        "timer"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }

    private func durationText(
        _ interval: TimeInterval
    ) -> String {
        let total =
            max(
                0,
                Int(interval.rounded())
            )

        let minutes =
            total / 60

        let seconds =
            total % 60

        return String(
            format:
                "%02d:%02d",
            minutes,
            seconds
        )
    }
}
