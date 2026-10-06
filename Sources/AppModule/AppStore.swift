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

    @Published
    var apiKey: String = KeychainStore.loadAPIKey()

    let sessionStartedAt = Date()

    private let repository: any BarRepository

    private let validationDefaultsKey =
        "MarketSignalLab.UniverseValidation.v2"

    private var diagnosticEvents: [DiagnosticEvent] = []

    init(
        repository: any BarRepository = JSONBarRepository()
    ) {
        self.repository = repository

        loadValidationCache()

        do {
            assets = try UniverseLoader.load()

            selectedAsset =
                assets.first(where: { $0.symbol == "QQQ" })
                ?? assets.first

            log("info", "Universe loaded with \(assets.count) assets.")

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

        do {
            bars = try await repository.load(
                symbol: asset.symbol,
                timeframe: "1min"
            )

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
            selectedStoredBars: bars.count,
            selectedLatestClose: bars.last?.close,
            systemMessage: status.message,
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
