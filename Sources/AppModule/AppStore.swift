import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {

    @Published private(set) var assets: [AssetConfig] = []
    @Published var selectedAsset: AssetConfig?
    @Published private(set) var bars: [MarketBar] = []
    @Published private(set) var status = ProviderStatus()

    @Published private(set)
    var validations: [String: AssetValidationState] = [:]

    @Published private(set)
    var isValidatingUniverse = false

    @Published private(set)
    var validationProgress = 0

    @Published private(set)
    var diagnosticsURL: URL?

    @Published private(set)
    var storageStats = BarStorageStats.empty

    @Published private(set)
    var isDownloadingHistory = false

    @Published private(set)
    var historyCompletedChunks = 0

    @Published private(set)
    var historyTotalChunks = 0

    @Published private(set)
    var historyBarsSaved = 0

    @Published private(set)
    var historyMessage = "Historical downloader ready."

    @Published private(set)
    var researchRows: [ResearchRow] = []

    @Published private(set)
    var researchFolds: [WalkForwardFold] = []

    @Published private(set)
    var researchSummary: ResearchDatasetSummary?

    @Published private(set)
    var isBuildingResearchDataset = false

    @Published private(set)
    var researchMessage = "Research dataset not built yet."

    @Published private(set)
    var labelCalibration: LabelCalibrationResult?

    @Published private(set)
    var isCalibratingLabels = false

    @Published private(set)
    var labelCalibrationMessage =
        "Label policies not calibrated yet."

    @Published private(set)
    var storageOverview: [String: BarStorageStats] = [:]

    @Published private(set)
    var researchSummaryBySymbol: [String: ResearchDatasetSummary] = [:]

    @Published private(set)
    var researchFoldsBySymbol: [String: [WalkForwardFold]] = [:]

    @Published private(set)
    var labelCalibrationBySymbol: [String: LabelCalibrationResult] = [:]

    @Published private(set)
    var lockedLabelPolicies: [String: LockedLabelPolicyRecord] = [:]

    @Published private(set)
    var isLockingLabelPolicy = false

    @Published private(set)
    var policyLockMessage =
        "No label policy locked for the selected symbol."

    @Published private(set)
    var isAddingCustomAsset = false

    @Published private(set)
    var customAssetMessage = ""

    @Published private(set)
    var isBuildingAllResearch = false

    @Published private(set)
    var allResearchProgress = 0

    @Published private(set)
    var allResearchTotal = 0

    @Published private(set)
    var allResearchMessage =
        "Cross-symbol research overview ready."

    @Published
    var apiKey: String = KeychainStore.loadAPIKey()

    let sessionStartedAt = Date()

    private let repository: any BarRepository

    private let validationDefaultsKey =
        "MarketSignalLab.UniverseValidation.v2"

    private let customAssetsDefaultsKey =
        "MarketSignalLab.CustomAssets.v1"

    private let lockedLabelPoliciesDefaultsKey =
        "MarketSignalLab.LockedLabelPolicies.v1"

    private var diagnosticEvents: [DiagnosticEvent] = []

    init(
        repository: any BarRepository = PartitionedJSONBarRepository()
    ) {
        self.repository = repository

        loadValidationCache()
        loadLockedLabelPolicies()

        do {
            let builtIn = try UniverseLoader.load()
            let custom = loadCustomAssets()

            var merged: [String: AssetConfig] = [:]

            for asset in builtIn + custom {
                merged[asset.symbol.uppercased()] = asset
            }

            assets = merged.values.sorted {
                lhs, rhs in

                if lhs.role != rhs.role {
                    return lhs.role == .tradeable
                }

                return lhs.symbol < rhs.symbol
            }

            selectedAsset =
                assets.first(where: { $0.symbol == "QQQ" })
                ?? assets.first

            log(
                "info",
                "Universe loaded with \(assets.count) assets (\(custom.count) custom)."
            )

        } catch {
            status.message =
                "Universe load failed: \(error.localizedDescription)"

            log("error", status.message)
        }
    }

    var tradeableAssets: [AssetConfig] {
        assets.filter { $0.role == .tradeable }
    }

    var contextAssets: [AssetConfig] {
        assets.filter { $0.role == .context }
    }

    var customAssets: [AssetConfig] {
        loadCustomAssets()
    }

    func isCustomAsset(
        _ asset: AssetConfig
    ) -> Bool {
        Set(
            loadCustomAssets().map {
                $0.symbol.uppercased()
            }
        )
        .contains(
            asset.symbol.uppercased()
        )
    }

    func lockedLabelPolicy(
        for asset: AssetConfig
    ) -> LockedLabelPolicyRecord? {
        lockedLabelPolicies[
            asset.symbol
        ]
    }

    var selectedLockedLabelPolicy:
        LockedLabelPolicyRecord? {

        guard let asset = selectedAsset else {
            return nil
        }

        return lockedLabelPolicy(
            for: asset
        )
    }

    func addCustomAsset(
        symbol rawSymbol: String,
        displayName rawDisplayName: String,
        assetClass: AssetClass
    ) async {
        let symbol = rawSymbol
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .uppercased()

        guard !symbol.isEmpty else {
            customAssetMessage =
                "Enter a ticker or provider symbol."
            return
        }

        guard assets.contains(
            where: {
                $0.symbol.uppercased() == symbol
            }
        ) == false else {
            customAssetMessage =
                "\(symbol) is already in the watchlist."
            return
        }

        isAddingCustomAsset = true
        customAssetMessage =
            "Checking \(symbol) with Twelve Data…"

        defer {
            isAddingCustomAsset = false
        }

        let displayName = rawDisplayName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let asset = AssetConfig(
            symbol: symbol,
            displayName:
                displayName.isEmpty
                ? symbol
                : displayName,
            assetClass: assetClass,
            role: .tradeable,
            timezone:
                assetClass == .crypto
                ? "UTC"
                : "America/New_York",
            modelGroup: "custom",
            optionsEnabled:
                assetClass == .equity
                || assetClass == .etf,
            dataSymbol: nil
        )

        let key = apiKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var validation = AssetValidationState.unknown

        if !key.isEmpty {
            let validator = TwelveDataSymbolValidator(
                apiKey: key
            )

            validation = await validator.validate(
                asset: asset
            )

            if validation.availability == .unavailable
                || validation.availability == .restricted {

                customAssetMessage =
                    "Could not add \(symbol): \(validation.message)"
                return
            }
        }

        var custom = loadCustomAssets()
        custom.append(asset)
        saveCustomAssets(custom)

        assets.append(asset)
        assets.sort {
            lhs, rhs in

            if lhs.role != rhs.role {
                return lhs.role == .tradeable
            }

            return lhs.symbol < rhs.symbol
        }

        validations[symbol] = validation
        saveValidationCache()

        selectedAsset = asset

        customAssetMessage =
            "Added \(symbol) to the watchlist."

        log(
            "info",
            customAssetMessage
        )

        await loadLocalBars()
    }

    func removeCustomAsset(
        _ asset: AssetConfig
    ) {
        var custom = loadCustomAssets()

        custom.removeAll {
            $0.symbol.uppercased()
                == asset.symbol.uppercased()
        }

        saveCustomAssets(custom)

        assets.removeAll {
            $0.symbol.uppercased()
                == asset.symbol.uppercased()
        }

        validations.removeValue(
            forKey: asset.symbol
        )

        storageOverview.removeValue(
            forKey: asset.symbol
        )

        researchSummaryBySymbol.removeValue(
            forKey: asset.symbol
        )

        researchFoldsBySymbol.removeValue(
            forKey: asset.symbol
        )

        labelCalibrationBySymbol.removeValue(
            forKey: asset.symbol
        )

        lockedLabelPolicies.removeValue(
            forKey: asset.symbol
        )

        saveLockedLabelPolicies()

        if selectedAsset?.symbol == asset.symbol {
            selectedAsset =
                assets.first(where: {
                    $0.symbol == "QQQ"
                })
                ?? assets.first
        }

        customAssetMessage =
            "Removed \(asset.symbol) from the watchlist."

        log(
            "info",
            customAssetMessage
        )
    }

    func refreshStorageOverview() async {
        var result: [String: BarStorageStats] = [:]

        for asset in assets {
            if let stats = try? await repository.stats(
                symbol: asset.symbol,
                timeframe: "1min"
            ) {
                result[asset.symbol] = stats
            }
        }

        storageOverview = result
    }

    var availableCount: Int {
        validations.values.filter {
            $0.availability == .available
        }.count
    }

    var restrictedCount: Int {
        validations.values.filter {
            $0.availability == .restricted
        }.count
    }

    var unavailableCount: Int {
        validations.values.filter {
            $0.availability == .unavailable
        }.count
    }

    var rateLimitedCount: Int {
        validations.values.filter {
            $0.availability == .rateLimited
        }.count
    }

    func validationState(
        for asset: AssetConfig
    ) -> AssetValidationState {
        validations[asset.symbol] ?? .unknown
    }

    func saveAPIKey() {
        do {
            try KeychainStore.saveAPIKey(
                apiKey.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )

            status.message = "API key saved securely."
            log("info", status.message)

        } catch {
            status.message =
                "Could not save API key: \(error.localizedDescription)"

            log("error", status.message)
        }
    }

    func validateUniverse(
        force: Bool = false
    ) async {
        let key = apiKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !key.isEmpty else {
            status.message =
                "Add your Twelve Data API key before validating."
            log("warning", status.message)
            return
        }

        guard !isValidatingUniverse else {
            return
        }

        isValidatingUniverse = true
        validationProgress = 0

        defer {
            isValidatingUniverse = false
            saveValidationCache()
        }

        status.message = force
            ? "Force-validating \(assets.count) symbols against Twelve Data with API pacing…"
            : "Validating unresolved symbols against Twelve Data with API pacing…"

        log("info", status.message)

        let validator = TwelveDataSymbolValidator(apiKey: key)

        for (index, asset) in assets.enumerated() {
            let previous = validations[asset.symbol]

            if !force, previous?.isStable == true {
                validationProgress = index + 1
                continue
            }

            validations[asset.symbol] = .checking

            var result = await validator.validate(asset: asset)

            if result.availability == .rateLimited {
                let wait = max(
                    1,
                    min(result.retryAfterSeconds ?? 65, 120)
                )

                status.message =
                    "Rate limited on \(asset.symbol). Waiting \(Int(wait))s, then retrying once…"

                log("warning", status.message)

                let nanos = UInt64(wait * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)

                result = await validator.validate(asset: asset)
            }

            if result.availability == .rateLimited,
               let previous,
               previous.isStable {

                validations[asset.symbol] = previous

                log(
                    "warning",
                    "Temporary rate limit on \(asset.symbol); preserved previous stable status \(previous.availability.rawValue)."
                )

            } else {
                validations[asset.symbol] = result

                let level = result.availability == .available
                    ? "info"
                    : (result.availability == .error || result.availability == .rateLimited ? "warning" : "info")

                log(
                    level,
                    "\(asset.symbol): \(result.availability.rawValue) — \(result.message)"
                )
            }

            validationProgress = index + 1
            saveValidationCache()
        }

        status.message =
            "Validation finished: \(availableCount) available, \(restrictedCount) restricted, \(unavailableCount) unavailable, \(rateLimitedCount) rate limited."

        log("info", status.message)
    }

    func loadLocalBars() async {
        guard let asset = selectedAsset else {
            return
        }

        if researchSummary?.symbol != asset.symbol {
            researchRows = []
            researchSummary =
                researchSummaryBySymbol[asset.symbol]

            researchFolds =
                researchFoldsBySymbol[asset.symbol]
                ?? []

            labelCalibration =
                labelCalibrationBySymbol[asset.symbol]

            researchMessage =
                researchSummary == nil
                ? "Research dataset not built yet."
                : "Loaded cached research summary for \(asset.symbol)."

            labelCalibrationMessage =
                labelCalibration == nil
                ? "Label policies not calibrated yet."
                : "Loaded cached label calibration for \(asset.symbol)."

            policyLockMessage =
                lockedLabelPolicies[asset.symbol] == nil
                ? "No label policy locked for \(asset.symbol)."
                : "Loaded locked label policy for \(asset.symbol)."
        }

        do {
            bars = try await repository.load(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageStats = try await repository.stats(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageOverview[asset.symbol] =
                storageStats

            if bars.isEmpty {
                status.message =
                    "No local bars yet for \(asset.symbol)."
            } else {
                status.message =
                    "Loaded \(bars.count) local bars for \(asset.symbol)."
            }

            log("info", status.message)

        } catch {
            status.message =
                "Local load failed: \(error.localizedDescription)"

            log("error", status.message)
        }
    }

    func refreshSelected(
        outputSize: Int = 120
    ) async {
        guard let asset = selectedAsset else {
            return
        }

        let validation = validationState(for: asset)

        if validation.availability == .restricted
            || validation.availability == .unavailable {

            status.message =
                "\(asset.symbol) is not available on the current provider/account: \(validation.message)"

            log("warning", status.message)
            return
        }

        status.isLoading = true
        status.message = "Fetching \(asset.symbol)…"

        defer {
            status.isLoading = false
        }

        do {
            let provider = TwelveDataProvider(apiKey: apiKey)

            let downloaded = try await provider.bars(
                for: asset,
                interval: "1min",
                outputSize: outputSize
            )

            try await repository.save(downloaded)

            bars = try await repository.load(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageStats = try await repository.stats(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageOverview[asset.symbol] =
                storageStats

            validations[asset.symbol] = AssetValidationState(
                availability: .available,
                message: "\(asset.providerSymbol) works on the current Twelve Data account.",
                checkedAt: Date()
            )

            saveValidationCache()

            status.lastRefresh = Date()
            status.message =
                "Saved \(downloaded.count) bars. Local total: \(bars.count)."

            log("info", status.message)

        } catch let error as MarketDataError {
            switch error {
            case .rateLimited(let message, let retryAfter):
                let old = validations[asset.symbol]

                if old?.isStable != true {
                    validations[asset.symbol] = AssetValidationState(
                        availability: .rateLimited,
                        message: message,
                        checkedAt: Date(),
                        retryAfterSeconds: retryAfter
                    )
                }

                status.message = error.localizedDescription
                log("warning", status.message)

            default:
                status.message = error.localizedDescription
                log("error", status.message)
            }

        } catch {
            status.message = error.localizedDescription
            log("error", status.message)
        }
    }

    func estimatedHistoricalChunks(
        startDate: Date,
        endDate: Date
    ) -> Int {
        guard endDate > startDate else {
            return 0
        }

        let chunkSeconds: TimeInterval =
            3 * 24 * 60 * 60

        return Int(
            ceil(
                endDate.timeIntervalSince(startDate)
                / chunkSeconds
            )
        )
    }

    func downloadHistoricalData(
        startDate: Date,
        endDate: Date
    ) async {
        guard let asset = selectedAsset else {
            return
        }

        guard !isDownloadingHistory else {
            return
        }

        let key = apiKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !key.isEmpty else {
            historyMessage =
                "Add your Twelve Data API key first."
            return
        }

        guard endDate > startDate else {
            historyMessage =
                "End date must be later than start date."
            return
        }

        let maximumRange: TimeInterval =
            90 * 24 * 60 * 60

        guard endDate.timeIntervalSince(startDate)
                <= maximumRange else {
            historyMessage =
                "Phase 2A limits one 1-minute import to 90 days. Split larger history into multiple runs."
            return
        }

        isDownloadingHistory = true

        labelCalibration = nil
        labelCalibrationMessage =
            "Historical data changed; calibration cache cleared. Any locked policy remains frozen until explicitly changed."

        researchSummaryBySymbol.removeValue(
            forKey: asset.symbol
        )

        researchFoldsBySymbol.removeValue(
            forKey: asset.symbol
        )

        labelCalibrationBySymbol.removeValue(
            forKey: asset.symbol
        )

        historyCompletedChunks = 0
        historyBarsSaved = 0

        let chunks = historicalChunks(
            startDate: startDate,
            endDate: endDate
        )

        historyTotalChunks = chunks.count

        defer {
            isDownloadingHistory = false
        }

        let provider = TwelveDataProvider(
            apiKey: key
        )

        log(
            "info",
            "Historical import started for \(asset.symbol): \(chunks.count) chunks."
        )

        for (index, chunk) in chunks.enumerated() {
            historyMessage =
                "Downloading \(asset.symbol) chunk \(index + 1) / \(chunks.count)…"

            do {
                let downloaded =
                    try await provider.historicalBars(
                        for: asset,
                        interval: "1min",
                        startDate: chunk.start,
                        endDate: chunk.end
                    )

                try await repository.save(
                    downloaded
                )

                historyBarsSaved += downloaded.count

            } catch let error as MarketDataError {
                if case .noData = error {
                    log(
                        "info",
                        "No bars in historical chunk \(index + 1) for \(asset.symbol); continuing."
                    )
                } else {
                    historyMessage =
                        "Historical import stopped: \(error.localizedDescription)"

                    log(
                        "error",
                        historyMessage
                    )

                    historyCompletedChunks = index
                    return
                }

            } catch {
                historyMessage =
                    "Historical import stopped: \(error.localizedDescription)"

                log(
                    "error",
                    historyMessage
                )

                historyCompletedChunks = index
                return
            }

            historyCompletedChunks = index + 1
        }

        do {
            bars = try await repository.load(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageStats = try await repository.stats(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageOverview[asset.symbol] =
                storageStats

            historyMessage =
                "Historical import complete. Received \(historyBarsSaved) bars; local deduplicated total \(storageStats.count)."

            status.message = historyMessage
            status.lastRefresh = Date()

            log(
                "info",
                historyMessage
            )

        } catch {
            historyMessage =
                "Historical data saved, but local reload failed: \(error.localizedDescription)"

            log(
                "error",
                historyMessage
            )
        }
    }

    private func historicalChunks(
        startDate: Date,
        endDate: Date
    ) -> [(start: Date, end: Date)] {
        let chunkSeconds: TimeInterval =
            3 * 24 * 60 * 60

        var chunks: [(Date, Date)] = []
        var cursor = startDate

        while cursor < endDate {
            let next = min(
                cursor.addingTimeInterval(
                    chunkSeconds
                ),
                endDate
            )

            chunks.append(
                (cursor, next)
            )

            cursor = next
        }

        return chunks
    }

    func buildResearchDataset() async {
        guard let asset = selectedAsset else {
            return
        }

        guard !isBuildingResearchDataset else {
            return
        }

        isBuildingResearchDataset = true

        let lockedPolicy =
            lockedLabelPolicies[
                asset.symbol
            ]?.policy

        researchMessage =
            "Building features, labels and purged walk-forward folds for \(asset.symbol)…"

        defer {
            isBuildingResearchDataset = false
        }

        do {
            let localBars = try await repository.load(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            bars = localBars

            storageStats = try await repository.stats(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageOverview[asset.symbol] =
                storageStats

            guard localBars.count >= 300 else {
                researchRows = []
                researchFolds = []
                researchSummary = nil
                researchMessage =
                    "Only \(localBars.count) local 1-minute bars found. Open Historical Data and download at least one full session before building the research dataset."

                log(
                    "warning",
                    researchMessage
                )

                return
            }

            let result = await Task.detached(
                priority: .userInitiated
            ) {
                ResearchDatasetBuilder.build(
                    asset: asset,
                    bars: localBars,
                    labelPolicy: lockedPolicy
                )
            }.value

            researchRows = result.rows
            researchFolds = result.folds
            researchSummary = result.summary

            researchSummaryBySymbol[asset.symbol] =
                result.summary

            researchFoldsBySymbol[asset.symbol] =
                result.folds

            let policyText =
                result.summary.usesLockedPolicy
                ? "locked policy \(result.summary.labelPolicyName)"
                : "baseline label policy"

            researchMessage =
                "Research dataset ready: \(result.summary.rowCount) labeled rows, \(result.summary.featureCount) features, \(result.folds.count) purged walk-forward folds using \(policyText)."

            log(
                "info",
                researchMessage
            )

        } catch {
            researchRows = []
            researchFolds = []
            researchSummary = nil
            researchMessage =
                "Research dataset build failed: \(error.localizedDescription)"

            log(
                "error",
                researchMessage
            )
        }
    }

    func calibrateLabelPolicies() async {
        guard let asset = selectedAsset else {
            return
        }

        guard !isCalibratingLabels else {
            return
        }

        isCalibratingLabels = true
        labelCalibrationMessage =
            "Calibrating fixed and ATR-adaptive label policies for \(asset.symbol)…"

        defer {
            isCalibratingLabels = false
        }

        do {
            let localBars = try await repository.load(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            bars = localBars

            storageStats = try await repository.stats(
                symbol: asset.symbol,
                timeframe: "1min"
            )

            storageOverview[asset.symbol] =
                storageStats

            guard localBars.count >= 300 else {
                labelCalibration = nil
                labelCalibrationMessage =
                    "Need more historical 1-minute bars before label calibration."

                log(
                    "warning",
                    labelCalibrationMessage
                )

                return
            }

            if researchSummary?.symbol != asset.symbol
                || researchFolds.isEmpty {

                let baseline = await Task.detached(
                    priority: .userInitiated
                ) {
                    ResearchDatasetBuilder.build(
                        asset: asset,
                        bars: localBars
                    )
                }.value

                researchRows = baseline.rows
                researchFolds = baseline.folds
                researchSummary = baseline.summary
            }

            guard !researchFolds.isEmpty else {
                labelCalibration = nil
                labelCalibrationMessage =
                    "Label calibration requires session-safe walk-forward folds. Download more history first."

                log(
                    "warning",
                    labelCalibrationMessage
                )

                return
            }

            let folds = researchFolds

            let result = await Task.detached(
                priority: .userInitiated
            ) {
                LabelCalibrationEngine.calibrate(
                    asset: asset,
                    bars: localBars,
                    folds: folds
                )
            }.value

            guard let result,
                  let recommended =
                    result.recommended
            else {
                labelCalibration = nil
                labelCalibrationMessage =
                    "Label calibration produced no usable candidates."

                log(
                    "warning",
                    labelCalibrationMessage
                )

                return
            }

            labelCalibration = result
            labelCalibrationBySymbol[asset.symbol] =
                result

            let acceptanceText =
                recommended.meetsAcceptanceBand
                ? "accepted"
                : "best available, but outside the acceptance band"

            labelCalibrationMessage =
                "Recommended \(recommended.policy.name): LONG \(percentText(recommended.longTargetRate)), SHORT \(percentText(recommended.shortTargetRate)), score \(String(format: "%.1f", recommended.score)) — \(acceptanceText)."

            log(
                recommended.meetsAcceptanceBand
                    ? "info"
                    : "warning",
                labelCalibrationMessage
            )

        } catch {
            labelCalibration = nil
            labelCalibrationMessage =
                "Label calibration failed: \(error.localizedDescription)"

            log(
                "error",
                labelCalibrationMessage
            )
        }
    }

    func lockRecommendedLabelPolicy() async {
        guard let asset = selectedAsset else {
            return
        }

        guard !isLockingLabelPolicy else {
            return
        }

        guard
            let calibration = labelCalibration,
            let recommended =
                calibration.recommended,
            recommended.meetsAcceptanceBand
        else {
            policyLockMessage =
                "An accepted calibration is required before locking a label policy."

            log(
                "warning",
                policyLockMessage
            )

            return
        }

        isLockingLabelPolicy = true

        defer {
            isLockingLabelPolicy = false
        }

        let record = LockedLabelPolicyRecord(
            symbol: asset.symbol,
            policy: recommended.policy,
            lockedAt: Date(),
            calibrationScore:
                recommended.score,
            calibrationLongTargetRate:
                recommended.longTargetRate,
            calibrationShortTargetRate:
                recommended.shortTargetRate
        )

        lockedLabelPolicies[
            asset.symbol
        ] = record

        saveLockedLabelPolicies()

        policyLockMessage =
            "Locked \(recommended.policy.name) for \(asset.symbol). Rebuilding the research dataset with the frozen policy…"

        log(
            "info",
            policyLockMessage
        )

        await buildResearchDataset()

        if researchSummary?.usesLockedPolicy == true,
           researchSummary?.labelPolicyID
                == recommended.policy.id {

            policyLockMessage =
                "Policy locked and dataset rebuilt for \(asset.symbol): \(recommended.policy.name)."

            log(
                "info",
                policyLockMessage
            )
        }
    }

    func unlockLabelPolicy(
        for asset: AssetConfig
    ) {
        lockedLabelPolicies.removeValue(
            forKey: asset.symbol
        )

        saveLockedLabelPolicies()

        researchSummaryBySymbol.removeValue(
            forKey: asset.symbol
        )

        researchFoldsBySymbol.removeValue(
            forKey: asset.symbol
        )

        if selectedAsset?.symbol == asset.symbol {
            researchSummary = nil
            researchFolds = []
            researchRows = []
            policyLockMessage =
                "Unlocked label policy for \(asset.symbol). Rebuild the dataset to return to baseline labels."
        }

        log(
            "warning",
            "Unlocked label policy for \(asset.symbol)."
        )
    }

    private func percentText(
        _ value: Double
    ) -> String {
        String(
            format: "%.2f%%",
            value * 100
        )
    }

    func buildAllLocalResearchDatasets() async {
        guard !isBuildingAllResearch else {
            return
        }

        isBuildingAllResearch = true
        allResearchProgress = 0

        defer {
            isBuildingAllResearch = false
        }

        await refreshStorageOverview()

        let candidates = assets.filter {
            (storageOverview[$0.symbol]?.count ?? 0)
                >= 300
        }

        allResearchTotal = candidates.count

        guard !candidates.isEmpty else {
            allResearchMessage =
                "No symbols have at least 300 local 1-minute bars yet."
            return
        }

        allResearchMessage =
            "Building research summaries for \(candidates.count) symbols…"

        for asset in candidates {
            do {
                let localBars = try await repository.load(
                    symbol: asset.symbol,
                    timeframe: "1min"
                )

                let result = await Task.detached(
                    priority: .userInitiated
                ) {
                    ResearchDatasetBuilder.build(
                        asset: asset,
                        bars: localBars,
                        labelPolicy:
                            lockedLabelPolicies[
                                asset.symbol
                            ]?.policy
                    )
                }.value

                researchSummaryBySymbol[asset.symbol] =
                    result.summary

                researchFoldsBySymbol[asset.symbol] =
                    result.folds

            } catch {
                log(
                    "warning",
                    "Cross-symbol research failed for \(asset.symbol): \(error.localizedDescription)"
                )
            }

            allResearchProgress += 1
        }

        allResearchMessage =
            "Cross-symbol research complete: \(researchSummaryBySymbol.count) summaries cached."

        log(
            "info",
            allResearchMessage
        )
    }

    func prepareDiagnostics() {
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"

        let buildVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"

        let assetSnapshots = assets.map { asset in
            let validation = validationState(for: asset)

            return AssetDiagnosticSnapshot(
                symbol: asset.symbol,
                providerSymbol: asset.providerSymbol,
                role: asset.role.rawValue,
                availability: validation.availability.rawValue,
                validationMessage: validation.message,
                checkedAt: validation.checkedAt
            )
        }

        let snapshot = DiagnosticsSnapshot(
            generatedAt: Date(),
            appVersion: shortVersion,
            buildVersion: buildVersion,
            provider: "TwelveData",
            selectedSymbol: selectedAsset?.symbol,
            selectedStoredBars: storageStats.count,
            selectedEarliestBar: storageStats.earliest,
            selectedLatestBar: storageStats.latest,
            selectedLatestClose: bars.last?.close,
            systemMessage: status.message,
            historicalIsRunning: isDownloadingHistory,
            historicalCompletedChunks: historyCompletedChunks,
            historicalTotalChunks: historyTotalChunks,
            historicalBarsReceived: historyBarsSaved,
            historicalMessage: historyMessage,
            researchRowCount: researchSummary?.rowCount ?? 0,
            researchFeatureCount: researchSummary?.featureCount ?? 0,
            researchFoldCount: researchFolds.count,
            researchLongTargetRate: researchSummary?.longTargetRate,
            researchShortTargetRate: researchSummary?.shortTargetRate,
            researchMessage: researchMessage,
            labelCalibrationCandidateCount:
                labelCalibration?.candidates.count ?? 0,
            labelCalibrationRecommendedPolicy:
                labelCalibration?.recommended?.policy.name,
            labelCalibrationAccepted:
                labelCalibration?.recommended?.meetsAcceptanceBand,
            labelCalibrationLongTargetRate:
                labelCalibration?.recommended?.longTargetRate,
            labelCalibrationShortTargetRate:
                labelCalibration?.recommended?.shortTargetRate,
            labelCalibrationMessage:
                labelCalibrationMessage,
            labelCalibrationCandidates:
                labelCalibration?.candidates ?? [],
            lockedLabelPolicyName:
                selectedLockedLabelPolicy?.policy.name,
            lockedLabelPolicyID:
                selectedLockedLabelPolicy?.policy.id,
            lockedLabelPolicyAt:
                selectedLockedLabelPolicy?.lockedAt,
            researchUsesLockedPolicy:
                researchSummary?.usesLockedPolicy
                ?? false,
            availableCount: availableCount,
            restrictedCount: restrictedCount,
            unavailableCount: unavailableCount,
            rateLimitedCount: rateLimitedCount,
            assets: assetSnapshots,
            events: Array(diagnosticEvents.suffix(100))
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(snapshot)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd_HHmmss"

            let fileName =
                "MarketSignalLab_diagnostics_\(formatter.string(from: Date())).json"

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            try data.write(to: url, options: [.atomic])

            diagnosticsURL = url
            status.message = "Diagnostics ready to share."
            log("info", "Diagnostics export created: \(fileName)")

        } catch {
            diagnosticsURL = nil
            status.message =
                "Could not prepare diagnostics: \(error.localizedDescription)"

            log("error", status.message)
        }
    }

    private func log(
        _ level: String,
        _ message: String
    ) {
        diagnosticEvents.append(
            DiagnosticEvent(
                timestamp: Date(),
                level: level,
                message: message
            )
        )

        if diagnosticEvents.count > 200 {
            diagnosticEvents.removeFirst(
                diagnosticEvents.count - 200
            )
        }
    }

    private func loadCustomAssets() -> [AssetConfig] {
        guard
            let data = UserDefaults.standard.data(
                forKey: customAssetsDefaultsKey
            )
        else {
            return []
        }

        return (
            try? JSONDecoder().decode(
                [AssetConfig].self,
                from: data
            )
        ) ?? []
    }

    private func saveCustomAssets(
        _ custom: [AssetConfig]
    ) {
        guard let data = try? JSONEncoder().encode(
            custom
        ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: customAssetsDefaultsKey
        )
    }

    private func saveLockedLabelPolicies() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy =
                .iso8601

            let data = try encoder.encode(
                lockedLabelPolicies
            )

            UserDefaults.standard.set(
                data,
                forKey:
                    lockedLabelPoliciesDefaultsKey
            )

        } catch {
            print(
                "Could not save locked label policies:",
                error.localizedDescription
            )
        }
    }

    private func loadLockedLabelPolicies() {
        guard
            let data = UserDefaults.standard.data(
                forKey:
                    lockedLabelPoliciesDefaultsKey
            )
        else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy =
                .iso8601

            lockedLabelPolicies =
                try decoder.decode(
                    [String: LockedLabelPolicyRecord].self,
                    from: data
                )

        } catch {
            lockedLabelPolicies = [:]
        }
    }

    private func saveValidationCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(validations)

            UserDefaults.standard.set(
                data,
                forKey: validationDefaultsKey
            )

        } catch {
            print(
                "Could not save validation cache:",
                error.localizedDescription
            )
        }
    }

    private func loadValidationCache() {
        guard
            let data = UserDefaults.standard.data(
                forKey: validationDefaultsKey
            )
        else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            validations = try decoder.decode(
                [String: AssetValidationState].self,
                from: data
            )

        } catch {
            validations = [:]
        }
    }
}
