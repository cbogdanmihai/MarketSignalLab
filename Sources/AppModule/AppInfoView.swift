import SwiftUI
import UIKit

struct AppInfoView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var store: AppStore

    private let fallbackVersion = "0.7.6"
    private let fallbackBuild = "38"
    private let releaseName = "Phase 2C.5 — Nested Ridge Regularization"
    private let repositoryName = "cbogdanmihai/MarketSignalLab.swiftpm"
    private let sourceBranch = "main"

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? fallbackVersion
    }

    private var buildVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? fallbackBuild
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Running build") {
                    LabeledContent(
                        "App",
                        value: "MarketSignalLab"
                    )

                    LabeledContent(
                        "Version",
                        value: appVersion
                    )

                    LabeledContent(
                        "Build",
                        value: buildVersion
                    )

                    LabeledContent(
                        "Release",
                        value: releaseName
                    )

                    LabeledContent(
                        "Repository",
                        value: repositoryName
                    )

                    LabeledContent(
                        "Branch",
                        value: sourceBranch
                    )
                }

                Section("Clock") {
                    TimelineView(
                        .periodic(
                            from: .now,
                            by: 1
                        )
                    ) { context in
                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {
                            LabeledContent(
                                "Device time",
                                value: formattedLocal(
                                    context.date
                                )
                            )

                            LabeledContent(
                                "UTC",
                                value: formattedUTC(
                                    context.date
                                )
                            )
                        }
                    }

                    LabeledContent(
                        "Timezone",
                        value: TimeZone.current.identifier
                    )

                    LabeledContent(
                        "Session started",
                        value: formattedLocal(
                            store.sessionStartedAt
                        )
                    )

                    if let lastRefresh = store.status.lastRefresh {
                        LabeledContent(
                            "Last data refresh",
                            value: formattedLocal(
                                lastRefresh
                            )
                        )
                    } else {
                        LabeledContent(
                            "Last data refresh",
                            value: "None"
                        )
                    }
                }

                Section("Runtime") {
                    LabeledContent(
                        "iPadOS",
                        value: UIDevice.current.systemVersion
                    )

                    LabeledContent(
                        "Device",
                        value: UIDevice.current.model
                    )

                    LabeledContent(
                        "Locale",
                        value: Locale.current.identifier
                    )

                    LabeledContent(
                        "Provider",
                        value: "TwelveData"
                    )

                    LabeledContent(
                        "Universe",
                        value: "\(store.assets.count) assets"
                    )

                    LabeledContent(
                        "Custom tickers",
                        value: String(
                            store.customAssets.count
                        )
                    )

                    LabeledContent(
                        "Selected",
                        value: store.selectedAsset?.symbol ?? "None"
                    )

                    LabeledContent(
                        "Selected local bars",
                        value: String(store.storageStats.count)
                    )

                    LabeledContent(
                        "History progress",
                        value: store.isDownloadingHistory
                            ? "\(store.historyCompletedChunks) / \(store.historyTotalChunks)"
                            : "Idle"
                    )

                    LabeledContent(
                        "Research rows",
                        value: String(
                            store.researchSummary?.rowCount ?? 0
                        )
                    )

                    LabeledContent(
                        "Walk-forward folds",
                        value: String(
                            store.researchFolds.count
                        )
                    )

                    LabeledContent(
                        "Label calibration",
                        value:
                            store.labelCalibration?.recommended?.policy.name
                            ?? "Not run"
                    )

                    LabeledContent(
                        "Calibration accepted",
                        value:
                            store.labelCalibration?.recommended?.meetsAcceptanceBand == true
                            ? "Yes"
                            : "No"
                    )

                    LabeledContent(
                        "Locked label policy",
                        value:
                            store.selectedLockedLabelPolicy?.policy.name
                            ?? "None"
                    )

                    LabeledContent(
                        "Dataset uses lock",
                        value:
                            store.researchSummary?.usesLockedPolicy == true
                            ? "Yes"
                            : "No"
                    )

                    LabeledContent(
                        "Baseline",
                        value:
                            store.baselineResult == nil
                            ? "Not run"
                            : (
                                store.baselineResult?
                                    .passesInitialGate
                                == true
                                ? "PASS"
                                : "REVIEW"
                            )
                    )

                    LabeledContent(
                        "Baseline variant",
                        value:
                            store.baselineResult?
                                .variant
                                .title
                            ?? "—"
                    )

                    LabeledContent(
                        "Baseline candidates",
                        value:
                            String(
                                store
                                    .baselineCandidates
                                    .count
                            )
                    )

                    LabeledContent(
                        "LONG Brier skill",
                        value:
                            store.baselineResult
                            .map {
                                String(
                                    format:
                                        "%.1f%%",
                                    $0.meanLongSkill
                                        * 100
                                )
                            }
                            ?? "—"
                    )

                    LabeledContent(
                        "SHORT Brier skill",
                        value:
                            store.baselineResult
                            .map {
                                String(
                                    format:
                                        "%.1f%%",
                                    $0.meanShortSkill
                                        * 100
                                )
                            }
                            ?? "—"
                    )

                    LabeledContent(
                        "Bulk history",
                        value:
                            store.isDownloadingAllHistory
                            ? "\(store.historyBatchCompletedAssets) / \(store.historyBatchTotalAssets)"
                            : "Idle"
                    )
                }

                Section("Universe status") {
                    LabeledContent(
                        "Available",
                        value: String(store.availableCount)
                    )

                    LabeledContent(
                        "Restricted",
                        value: String(store.restrictedCount)
                    )

                    LabeledContent(
                        "Unavailable",
                        value: String(store.unavailableCount)
                    )

                    LabeledContent(
                        "Rate limited",
                        value: String(store.rateLimitedCount)
                    )
                }

                Section("System message") {
                    Text(store.status.message)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("App Info")
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formattedLocal(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        return formatter.string(from: date)
    }

    private func formattedUTC(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter.string(from: date)
    }
}
