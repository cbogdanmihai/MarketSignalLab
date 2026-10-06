import Foundation

protocol SymbolValidator: Sendable {
    func validate(asset: AssetConfig) async -> AssetValidationState
}

struct TwelveDataSymbolValidator: SymbolValidator {
    let apiKey: String

    func validate(asset: AssetConfig) async -> AssetValidationState {
        let provider = TwelveDataProvider(apiKey: apiKey)

        do {
            _ = try await provider.bars(
                for: asset,
                interval: "1min",
                outputSize: 1
            )

            return AssetValidationState(
                availability: .available,
                message: "\(asset.providerSymbol) works on the current Twelve Data account.",
                checkedAt: Date()
            )

        } catch let error as MarketDataError {
            switch error {
            case .missingAPIKey:
                return AssetValidationState(
                    availability: .error,
                    message: "Missing API key.",
                    checkedAt: Date()
                )

            case .rateLimited(let message, let retryAfter):
                return AssetValidationState(
                    availability: .rateLimited,
                    message: message,
                    checkedAt: Date(),
                    retryAfterSeconds: retryAfter
                )

            case .badHTTPStatus(let code):
                let availability: ProviderAvailability =
                    (code == 401 || code == 403) ? .restricted : .error

                return AssetValidationState(
                    availability: availability,
                    message: "HTTP \(code).",
                    checkedAt: Date()
                )

            case .provider(let message):
                return classifyProviderMessage(message)

            case .noData:
                return AssetValidationState(
                    availability: .unavailable,
                    message: "Provider returned no market data.",
                    checkedAt: Date()
                )

            case .invalidURL,
                 .decoding,
                 .invalidTimezone:
                return AssetValidationState(
                    availability: .error,
                    message: error.localizedDescription,
                    checkedAt: Date()
                )
            }

        } catch {
            return AssetValidationState(
                availability: .error,
                message: error.localizedDescription,
                checkedAt: Date()
            )
        }
    }

    private func classifyProviderMessage(
        _ message: String
    ) -> AssetValidationState {
        let text = message.lowercased()

        let rateLimitWords = [
            "rate limit",
            "too many requests",
            "api credits",
            "429"
        ]

        let restrictedWords = [
            "premium",
            "subscription",
            "plan",
            "access",
            "not authorized",
            "not authorised"
        ]

        let unavailableWords = [
            "symbol not found",
            "invalid symbol",
            "parameter is missing or invalid",
            "does not exist",
            "not supported",
            "no data"
        ]

        if rateLimitWords.contains(where: { text.contains($0) }) {
            return AssetValidationState(
                availability: .rateLimited,
                message: message,
                checkedAt: Date()
            )
        }

        if restrictedWords.contains(where: { text.contains($0) }) {
            return AssetValidationState(
                availability: .restricted,
                message: message,
                checkedAt: Date()
            )
        }

        if unavailableWords.contains(where: { text.contains($0) }) {
            return AssetValidationState(
                availability: .unavailable,
                message: message,
                checkedAt: Date()
            )
        }

        return AssetValidationState(
            availability: .error,
            message: message,
            checkedAt: Date()
        )
    }
}
