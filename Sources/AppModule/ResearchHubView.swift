import SwiftUI
import Charts
import Foundation

private enum ResearchHubScope: String, CaseIterable, Identifiable {
    case symbol = "Symbol"
    case all = "All Symbols"

    var id: String {
        rawValue
    }
}

struct ResearchHubView: View {
    @EnvironmentObject
    private var store: AppStore

    @Environment(\.terminalDensityScale)
    private var densityScale

    @State
    private var scope: ResearchHubScope = .symbol

    private var displayedLongTarget: Double {
        store.labelCalibration?.recommended?.longTargetRate
        ?? store.researchSummary?.longTargetRate
        ?? 0
    }

    private var displayedShortTarget: Double {
        store.labelCalibration?.recommended?.shortTargetRate
        ?? store.researchSummary?.shortTargetRate
        ?? 0
    }

    private var displayedLongTimeout: Double {
        store.labelCalibration?.recommended?.longTimeoutRate
        ?? store.researchSummary?.longTimeoutRate
        ?? 0
    }

    private var displayedShortTimeout: Double {
        store.labelCalibration?.recommended?.shortTimeoutRate
        ?? store.researchSummary?.shortTimeoutRate
        ?? 0
    }

    private var acceptanceLow: Double {
        store.labelCalibration?.targetBandLow
        ?? 0.08
    }

    private var acceptanceHigh: Double {
        store.labelCalibration?.targetBandHigh
        ?? 0.20
    }

    private var labelQualitySubtitle: String {
        if let policy =
            store.labelCalibration?
                .recommended?
                .policy.name {

            return "Recommended calibration · \(policy)"
        }

        return "Baseline target-before-stop distribution"
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                header

                if scope == .symbol {
                    symbolResearch
                } else {
                    allSymbolsResearch
                }
            }
            .padding(
                20 * densityScale
            )
        }
        .background(
            Color(
                uiColor:
                    .secondarySystemBackground
            )
        )
        .task {
            await store.refreshStorageOverview()
        }
    }

    private var header: some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text("Research Lab")
                    .font(.title.bold())

                Text(
                    "Causal features · label calibration · walk-forward validation"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Picker(
                "Scope",
                selection: $scope
            ) {
                ForEach(
                    ResearchHubScope.allCases
                ) { item in
                    Text(item.rawValue)
                        .tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(
                width:
                    260 * densityScale
            )

            TerminalDensityControl()
        }
    }

    private var symbolResearch: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            symbolToolbar

            if let summary = store.researchSummary {
                metricGrid(summary)

                decisionBanner(summary)

                labelQuality(summary)

                walkForwardSection

                calibrationSection

            } else {
                emptyResearchState
            }
        }
    }

    private var symbolToolbar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(
                    store.tradeableAssets
                ) { asset in
                    Button {
                        select(asset)
                    } label: {
                        Label(
                            asset.symbol,
                            systemImage:
                                asset.assetClass == .crypto
                                ? "bitcoinsign.circle"
                                : "chart.line.uptrend.xyaxis"
                        )
                    }
                }

                Divider()

                ForEach(
                    store.contextAssets
                ) { asset in
                    Button {
                        select(asset)
                    } label: {
                        Text(
                            "\(asset.symbol) · context"
                        )
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(
                        store.selectedAsset?.symbol
                        ?? "Choose symbol"
                    )
                    .font(.headline)

                    Image(
                        systemName:
                            "chevron.down"
                    )
                    .font(.caption)
                }
                .padding(
                    .horizontal,
                    12
                )
                .padding(
                    .vertical,
                    8
                )
                .background(
                    .thinMaterial,
                    in:
                        RoundedRectangle(
                            cornerRadius: 9
                        )
                )
            }

            if let asset = store.selectedAsset {
                Text(asset.displayName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task {
                    await store.loadLocalBars()
                    await store.buildResearchDataset()
                }
            } label: {
                Label(
                    store.isBuildingResearchDataset
                    ? "Building…"
                    : "Build Dataset",
                    systemImage:
                        "tablecells"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                store.isBuildingResearchDataset
                || store.isDownloadingHistory
                || store.isValidatingUniverse
            )

            Button {
                Task {
                    await store.calibrateLabelPolicies()
                }
            } label: {
                Label(
                    store.isCalibratingLabels
                    ? "Calibrating…"
                    : "Calibrate Labels",
                    systemImage:
                        "slider.horizontal.3"
                )
            }
            .buttonStyle(.bordered)
            .disabled(
                store.isCalibratingLabels
                || store.isBuildingResearchDataset
                || store.researchFolds.isEmpty
            )
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

    private func metricGrid(
        _ summary: ResearchDatasetSummary
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: 150
                    ),
                    spacing: 10
                )
            ],
            spacing: 10
        ) {
            MetricTile(
                title: "Local bars",
                value:
                    compact(
                        store.storageStats.count
                    ),
                subtitle:
                    coverageText
            )

            MetricTile(
                title: "Sessions",
                value:
                    String(
                        summary.sessionCount
                    ),
                subtitle:
                    summary.sessionCount >= 18
                    ? "Enough for baseline"
                    : "Need ≥ 18"
            )

            MetricTile(
                title: "Research rows",
                value:
                    compact(
                        summary.rowCount
                    ),
                subtitle:
                    "\(summary.featureCount) features"
            )

            MetricTile(
                title: "Walk-forward",
                value:
                    String(
                        store.researchFolds.count
                    ),
                subtitle:
                    "Session-safe folds"
            )

            MetricTile(
                title: "Label policy",
                value:
                    calibrationStatus,
                subtitle:
                    store.labelCalibration?
                    .recommended?
                    .policy.name
                    ?? "Not calibrated"
            )
        }
    }

    private func labelQuality(
        _ summary: ResearchDatasetSummary
    ) -> some View {
        ResearchCard(
            title: "Label Quality",
            subtitle:
                labelQualitySubtitle
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack(spacing: 22) {
                    RateMetric(
                        title: "LONG target",
                        value:
                            displayedLongTarget,
                        desired:
                            acceptanceLow...acceptanceHigh
                    )

                    RateMetric(
                        title: "SHORT target",
                        value:
                            displayedShortTarget,
                        desired:
                            acceptanceLow...acceptanceHigh
                    )

                    RateMetric(
                        title: "LONG timeout",
                        value:
                            displayedLongTimeout,
                        desired:
                            nil
                    )

                    RateMetric(
                        title: "SHORT timeout",
                        value:
                            displayedShortTimeout,
                        desired:
                            nil
                    )
                }

                Chart {
                    BarMark(
                        x: .value(
                            "Direction",
                            "LONG"
                        ),
                        y: .value(
                            "Target rate",
                            displayedLongTarget * 100
                        )
                    )
                    .foregroundStyle(
                        .green.gradient
                    )

                    BarMark(
                        x: .value(
                            "Direction",
                            "SHORT"
                        ),
                        y: .value(
                            "Target rate",
                            displayedShortTarget * 100
                        )
                    )
                    .foregroundStyle(
                        .red.gradient
                    )

                    RuleMark(
                        y: .value(
                            "Minimum",
                            acceptanceLow * 100
                        )
                    )
                    .foregroundStyle(
                        .orange
                    )
                    .lineStyle(
                        StrokeStyle(
                            dash: [4, 3]
                        )
                    )

                    RuleMark(
                        y: .value(
                            "Maximum",
                            acceptanceHigh * 100
                        )
                    )
                    .foregroundStyle(
                        .orange.opacity(0.7)
                    )
                    .lineStyle(
                        StrokeStyle(
                            dash: [4, 3]
                        )
                    )
                }
                .chartYScale(
                    domain: 0...25
                )
                .chartYAxis {
                    AxisMarks(
                        position: .trailing
                    ) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let number =
                                value.as(Double.self) {
                                Text(
                                    "\(number, specifier: "%.0f")%"
                                )
                            }
                        }
                    }
                }
                .frame(
                    height:
                        150 * densityScale
                )

                HStack(spacing: 8) {
                    Label(
                        "Acceptance band \(percent(acceptanceLow))–\(percent(acceptanceHigh))",
                        systemImage: "scope"
                    )

                    if store.labelCalibration?.recommended != nil {
                        Text(
                            "Showing recommended calibration, not the baseline label."
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func decisionBanner(
        _ summary: ResearchDatasetSummary
    ) -> some View {
        let calibration =
            store.labelCalibration?.recommended

        let title: String
        let detail: String
        let color: Color
        let icon: String

        if summary.sessionCount < 18 {
            title = "Collect more history"
            detail =
                "Only \(summary.sessionCount) independent sessions are available. Keep model training blocked."
            color = .orange
            icon = "clock.badge.exclamationmark"

        } else if let calibration,
                  calibration.meetsAcceptanceBand {
            title = "Label policy ready"
            detail =
                "\(calibration.policy.name) is inside the target-event acceptance band. Next: lock the policy before model training."
            color = .green
            icon = "checkmark.seal.fill"

        } else if let calibration {
            title = "Label policy needs refinement"
            detail =
                calibrationIssueText(
                    calibration
                )
            color = .orange
            icon = "slider.horizontal.3"

        } else {
            title = "Run label calibration"
            detail =
                "Data coverage is sufficient. Calibrate label policies before training so the test sessions remain untouched."
            color = .blue
            icon = "flask"
        }

        return HStack(
            alignment: .top,
            spacing: 12
        ) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            color.opacity(0.10),
            in:
                RoundedRectangle(
                    cornerRadius: 12
                )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12
            )
            .stroke(
                color.opacity(0.25),
                lineWidth: 1
            )
        )
    }

    private var walkForwardSection: some View {
        ResearchCard(
            title: "Walk-Forward Validation",
            subtitle:
                "Expanding chronological folds split on complete sessions"
        ) {
            if store.researchFolds.isEmpty {
                Text(
                    "No folds yet. Build the dataset after downloading enough history."
                )
                .foregroundStyle(.secondary)

            } else {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(
                        alignment: .top,
                        spacing: 10
                    ) {
                        ForEach(
                            store.researchFolds
                        ) { fold in
                            FoldCard(
                                fold: fold
                            )
                        }
                    }
                }
            }
        }
    }

    private var calibrationSection: some View {
        ResearchCard(
            title: "Label Calibration",
            subtitle:
                "Fixed and ATR-adaptive policies ranked without using test sessions"
        ) {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Text(
                    store.labelCalibrationMessage
                )
                .font(.callout)
                .textSelection(.enabled)

                if store.isCalibratingLabels {
                    ProgressView()
                }

                if let calibration =
                    store.labelCalibration,
                   let recommended =
                    calibration.recommended {

                    HStack(
                        alignment: .top,
                        spacing: 18
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {
                            Text("Recommended")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                recommended.policy.name
                            )
                            .font(.title3.bold())

                            Text(
                                recommended.meetsAcceptanceBand
                                ? "ACCEPTED"
                                : "BEST CANDIDATE"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(
                                recommended.meetsAcceptanceBand
                                ? Color.green
                                : Color.orange
                            )
                        }

                        Spacer()

                        RateMetric(
                            title: "LONG",
                            value:
                                recommended.longTargetRate,
                            desired:
                                calibration.targetBandLow...calibration.targetBandHigh
                        )

                        RateMetric(
                            title: "SHORT",
                            value:
                                recommended.shortTargetRate,
                            desired:
                                calibration.targetBandLow...calibration.targetBandHigh
                        )

                        VStack(
                            alignment: .trailing,
                            spacing: 4
                        ) {
                            Text("Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                recommended.score,
                                format:
                                    .number.precision(
                                        .fractionLength(1)
                                    )
                            )
                            .font(.title2.bold())
                            .monospacedDigit()
                        }
                    }

                    DisclosureGroup(
                        "Candidate ranking"
                    ) {
                        VStack(spacing: 8) {
                            ForEach(
                                calibration.candidates
                            ) { candidate in
                                CalibrationCandidateRow(
                                    candidate:
                                        candidate,
                                    targetLow:
                                        calibration.targetBandLow,
                                    targetHigh:
                                        calibration.targetBandHigh
                                )
                            }
                        }
                        .padding(
                            .top,
                            8
                        )
                    }
                }
            }
        }
    }

    private var emptyResearchState: some View {
        ResearchCard(
            title: "No research dataset",
            subtitle:
                "Build features and labels for the selected symbol"
        ) {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Text(
                    "Local bars: \(store.storageStats.count)"
                )
                .foregroundStyle(.secondary)

                Text(store.researchMessage)
                    .textSelection(.enabled)

                if store.storageStats.count < 300 {
                    Label(
                        "Download historical data first.",
                        systemImage:
                            "externaldrive.badge.exclamationmark"
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private var allSymbolsResearch: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text("Cross-symbol overview")
                        .font(.headline)

                    Text(
                        "Compare data coverage, dataset readiness and calibrated policies across the watchlist."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if store.isBuildingAllResearch {
                    ProgressView(
                        value:
                            Double(
                                store.allResearchProgress
                            ),
                        total:
                            Double(
                                max(
                                    store.allResearchTotal,
                                    1
                                )
                            )
                    )
                    .frame(width: 170)
                }

                Button {
                    Task {
                        await store.buildAllLocalResearchDatasets()
                    }
                } label: {
                    Label(
                        store.isBuildingAllResearch
                        ? "Building…"
                        : "Build All Local",
                        systemImage:
                            "square.stack.3d.up"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    store.isBuildingAllResearch
                )
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

            Text(store.allResearchMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            ResearchCard(
                title: "Universe Research Matrix",
                subtitle:
                    "Tap a symbol to open its research workspace"
            ) {
                VStack(spacing: 0) {
                    researchTableHeader

                    Divider()

                    ForEach(
                        store.assets
                    ) { asset in
                        researchSymbolRow(
                            asset
                        )

                        if asset.id
                            != store.assets.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var researchTableHeader: some View {
        HStack(spacing: 8) {
            Text("Symbol")
                .frame(
                    width: 110,
                    alignment: .leading
                )

            Text("Local bars")
                .frame(
                    width: 90,
                    alignment: .trailing
                )

            Text("Sessions")
                .frame(
                    width: 75,
                    alignment: .trailing
                )

            Text("Rows")
                .frame(
                    width: 90,
                    alignment: .trailing
                )

            Text("L target")
                .frame(
                    width: 80,
                    alignment: .trailing
                )

            Text("S target")
                .frame(
                    width: 80,
                    alignment: .trailing
                )

            Text("Calibration")
                .frame(
                    minWidth: 150,
                    alignment: .leading
                )

            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(
            .vertical,
            8
        )
    }

    private func researchSymbolRow(
        _ asset: AssetConfig
    ) -> some View {
        let stats =
            store.storageOverview[
                asset.symbol
            ]
            ?? .empty

        let summary =
            store.researchSummaryBySymbol[
                asset.symbol
            ]

        let calibration =
            store.labelCalibrationBySymbol[
                asset.symbol
            ]?
            .recommended

        return Button {
            select(asset)
            scope = .symbol
        } label: {
            HStack(spacing: 8) {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(asset.symbol)
                        .font(.headline)

                    Text(
                        asset.role.rawValue
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(
                    width: 110,
                    alignment: .leading
                )

                Text(
                    compact(stats.count)
                )
                .monospacedDigit()
                .frame(
                    width: 90,
                    alignment: .trailing
                )

                Text(
                    summary.map {
                        String(
                            $0.sessionCount
                        )
                    } ?? "—"
                )
                .monospacedDigit()
                .frame(
                    width: 75,
                    alignment: .trailing
                )

                Text(
                    summary.map {
                        compact(
                            $0.rowCount
                        )
                    } ?? "—"
                )
                .monospacedDigit()
                .frame(
                    width: 90,
                    alignment: .trailing
                )

                Text(
                    summary.map {
                        percent(
                            $0.longTargetRate
                        )
                    } ?? "—"
                )
                .monospacedDigit()
                .frame(
                    width: 80,
                    alignment: .trailing
                )

                Text(
                    summary.map {
                        percent(
                            $0.shortTargetRate
                        )
                    } ?? "—"
                )
                .monospacedDigit()
                .frame(
                    width: 80,
                    alignment: .trailing
                )

                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            calibration?
                            .meetsAcceptanceBand
                            == true
                            ? Color.green
                            : calibration == nil
                            ? Color.secondary
                            : Color.orange
                        )
                        .frame(
                            width: 7,
                            height: 7
                        )

                    Text(
                        calibration?
                        .policy.name
                        ?? "Not calibrated"
                    )
                    .lineLimit(1)
                }
                .frame(
                    minWidth: 150,
                    alignment: .leading
                )

                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(
                .vertical,
                9
            )
        }
        .buttonStyle(.plain)
    }

    private func select(
        _ asset: AssetConfig
    ) {
        store.selectedAsset = asset

        Task {
            await store.loadLocalBars()
        }
    }

    private var coverageText: String {
        guard
            let first =
                store.storageStats.earliest,
            let last =
                store.storageStats.latest
        else {
            return "No local history"
        }

        let days =
            Calendar.current.dateComponents(
                [.day],
                from: first,
                to: last
            ).day ?? 0

        return "~\(max(days, 0)) calendar days"
    }

    private var calibrationStatus: String {
        guard let recommended =
                store.labelCalibration?
                .recommended
        else {
            return "Pending"
        }

        return recommended
            .meetsAcceptanceBand
            ? "Accepted"
            : "Review"
    }

    private func calibrationIssueText(
        _ candidate: LabelCalibrationCandidateResult
    ) -> String {
        var issues: [String] = []

        if candidate.longTargetRate < acceptanceLow {
            issues.append(
                "LONG \(percent(candidate.longTargetRate)) is below \(percent(acceptanceLow))"
            )
        } else if candidate.longTargetRate > acceptanceHigh {
            issues.append(
                "LONG \(percent(candidate.longTargetRate)) is above \(percent(acceptanceHigh))"
            )
        }

        if candidate.shortTargetRate < acceptanceLow {
            issues.append(
                "SHORT \(percent(candidate.shortTargetRate)) is below \(percent(acceptanceLow))"
            )
        } else if candidate.shortTargetRate > acceptanceHigh {
            issues.append(
                "SHORT \(percent(candidate.shortTargetRate)) is above \(percent(acceptanceHigh))"
            )
        }

        if issues.isEmpty {
            return "Best candidate still misses a calibration acceptance condition."
        }

        return issues.joined(
            separator: " · "
        )
        + ". Expand/refine the calibration grid before Phase 2C."
    }

    private func readinessText(
        _ summary: ResearchDatasetSummary
    ) -> String {
        if summary.sessionCount < 18 {
            return "Not ready: collect at least 18 independent sessions."
        }

        if let recommended =
            store.labelCalibration?
            .recommended,
           recommended.meetsAcceptanceBand {

            return "Label policy accepted. Ready to lock policy before baseline model training."
        }

        return "Data coverage is sufficient; label calibration should be reviewed before model training."
    }

    private func readinessColor(
        _ summary: ResearchDatasetSummary
    ) -> Color {
        if summary.sessionCount < 18 {
            return .orange
        }

        if store.labelCalibration?
            .recommended?
            .meetsAcceptanceBand
            == true {

            return .green
        }

        return .orange
    }

    private func compact(
        _ value: Int
    ) -> String {
        value.formatted(
            .number.notation(
                .compactName
            )
        )
    }

    private func percent(
        _ value: Double
    ) -> String {
        String(
            format: "%.1f%%",
            value * 100
        )
    }
}

private struct ResearchCard<Content: View>: View {
    @Environment(\.terminalDensityScale)
    private var densityScale

    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(
            16 * densityScale
        )
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
}

private struct MetricTile: View {
    @Environment(\.terminalDensityScale)
    private var densityScale

    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(
            maxWidth: .infinity,
            minHeight:
                92 * densityScale,
            alignment: .leading
        )
        .padding(
            12 * densityScale
        )
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
}

private struct RateMetric: View {
    let title: String
    let value: Double
    let desired: ClosedRange<Double>?

    private var isInside: Bool {
        guard let desired else {
            return true
        }

        return desired.contains(value)
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                value,
                format:
                    .percent.precision(
                        .fractionLength(1)
                    )
            )
            .font(.title3.bold())
            .monospacedDigit()
            .foregroundStyle(
                isInside
                ? Color.primary
                : Color.orange
            )
        }
    }
}

private struct FoldCard: View {
    @Environment(\.terminalDensityScale)
    private var densityScale

    let fold: WalkForwardFold

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Fold \(fold.fold)")
                .font(.headline)

            foldLine(
                "Train",
                count: fold.trainCount
            )

            foldLine(
                "Validation",
                count: fold.validationCount
            )

            foldLine(
                "Test",
                count: fold.testCount
            )
        }
        .frame(
            width:
                220 * densityScale,
            alignment: .leading
        )
        .padding(
            12 * densityScale
        )
        .background(
            Color(
                uiColor:
                    .secondarySystemBackground
            ),
            in:
                RoundedRectangle(
                    cornerRadius: 10
                )
        )
    }

    private func foldLine(
        _ name: String,
        count: Int
    ) -> some View {
        HStack {
            Text(name)
                .foregroundStyle(.secondary)

            Spacer()

            Text(
                count.formatted()
            )
            .monospacedDigit()
        }
        .font(.caption)
    }
}

private struct CalibrationCandidateRow: View {
    let candidate: LabelCalibrationCandidateResult
    let targetLow: Double
    let targetHigh: Double

    private var statusText: String {
        if candidate.meetsAcceptanceBand {
            return "accepted"
        }

        var issues: [String] = []

        if candidate.longTargetRate < targetLow {
            issues.append("L low")
        } else if candidate.longTargetRate > targetHigh {
            issues.append("L high")
        }

        if candidate.shortTargetRate < targetLow {
            issues.append("S low")
        } else if candidate.shortTargetRate > targetHigh {
            issues.append("S high")
        }

        return issues.isEmpty
        ? "outside band"
        : issues.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    candidate.policy.name
                )
                .font(.subheadline.weight(.semibold))

                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(
                        candidate.meetsAcceptanceBand
                        ? Color.green
                        : Color.orange
                    )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 1
            ) {
                Text("LONG")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(
                    candidate.longTargetRate,
                    format:
                        .percent.precision(
                            .fractionLength(1)
                        )
                )
                .monospacedDigit()
            }

            VStack(
                alignment: .trailing,
                spacing: 1
            ) {
                Text("SHORT")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(
                    candidate.shortTargetRate,
                    format:
                        .percent.precision(
                            .fractionLength(1)
                        )
                )
                .monospacedDigit()
            }

            VStack(
                alignment: .trailing,
                spacing: 1
            ) {
                Text("SCORE")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(
                    candidate.score,
                    format:
                        .number.precision(
                            .fractionLength(1)
                        )
                )
                .font(.headline)
                .monospacedDigit()
            }
            .frame(
                width: 58,
                alignment: .trailing
            )
        }
        .font(.caption)
        .padding(
            .vertical,
            5
        )
    }
}
