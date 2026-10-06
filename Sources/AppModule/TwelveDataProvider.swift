import Foundation

struct TwelveDataProvider: MarketDataProvider {
    let apiKey: String

    var providerName: String { "TwelveData" }

    func bars(
        for asset: AssetConfig,
        interval: String = "1min",
        outputSize: Int = 120
    ) async throws -> [MarketBar] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MarketDataError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.twelvedata.com/time_series")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: asset.providerSymbol),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "outputsize", value: String(min(max(outputSize, 1), 5000))),
            URLQueryItem(name: "order", value: "ASC"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = components?.url else {
            throw MarketDataError.invalidURL
        }

        try await TwelveDataRateLimiter.shared.waitForTurn()

        let (data, response) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let providerError = try? decoder.decode(TwelveDataErrorResponse.self, from: data)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                let headerValue = http.value(forHTTPHeaderField: "Retry-After")
                let retryAfter = headerValue.flatMap(Double.init)
                let cooldown = retryAfter ?? 65

                await TwelveDataRateLimiter.shared.deferRequests(
                    for: cooldown
                )

                throw MarketDataError.rateLimited(
                    message: providerError?.message ?? "HTTP 429 from Twelve Data.",
                    retryAfter: cooldown
                )
            }

            if let creditsLeftText = http.value(
                forHTTPHeaderField: "api-credits-left"
            ),
               let creditsLeft = Int(creditsLeftText),
               creditsLeft <= 0 {

                await TwelveDataRateLimiter.shared.deferRequests(
                    for: 65
                )
            }

            if !(200...299).contains(http.statusCode) {
                if let message = providerError?.message, !message.isEmpty {
                    throw MarketDataError.provider(message)
                }
                throw MarketDataError.badHTTPStatus(http.statusCode)
            }
        }

        if providerError?.status == "error" {
            let message = providerError?.message ?? "Twelve Data returned an error."
            let lower = message.lowercased()

            if providerError?.code == 429
                || lower.contains("rate limit")
                || lower.contains("too many requests")
                || lower.contains("api credits") {

                throw MarketDataError.rateLimited(
                    message: message,
                    retryAfter: nil
                )
            }

            throw MarketDataError.provider(message)
        }

        let payload: TwelveDataResponse
        do {
            payload = try decoder.decode(TwelveDataResponse.self, from: data)
        } catch {
            throw MarketDataError.decoding(error.localizedDescription)
        }

        guard let timezone = TimeZone(identifier: payload.meta.exchangeTimezone) else {
            throw MarketDataError.invalidTimezone(payload.meta.exchangeTimezone)
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let result: [MarketBar] = payload.values.compactMap { value in
            guard
                let timestamp = formatter.date(from: value.datetime),
                let open = Double(value.open),
                let high = Double(value.high),
                let low = Double(value.low),
                let close = Double(value.close)
            else {
                return nil
            }

            return MarketBar(
                symbol: asset.symbol,
                timestamp: timestamp,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: value.volume.flatMap(Double.init),
                timeframe: payload.meta.interval,
                source: providerName
            )
        }

        guard !result.isEmpty else {
            throw MarketDataError.noData
        }

        return result
    }
}

private struct TwelveDataResponse: Decodable {
    struct Meta: Decodable {
        let symbol: String
        let interval: String
        let exchangeTimezone: String

        enum CodingKeys: String, CodingKey {
            case symbol
            case interval
            case exchangeTimezone = "exchange_timezone"
        }
    }

    struct Value: Decodable {
        let datetime: String
        let open: String
        let high: String
        let low: String
        let close: String
        let volume: String?
    }

    let meta: Meta
    let values: [Value]
}

private struct TwelveDataErrorResponse: Decodable {
    let code: Int?
    let status: String?
    let message: String?
}
