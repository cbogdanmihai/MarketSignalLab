import Foundation

enum AssetClass: String, Codable, CaseIterable, Sendable {
    case equity
    case etf
    case index
    case commodityProxy = "commodity_proxy"
    case crypto
    case macro
}

enum AssetRole: String, Codable, Sendable {
    case tradeable
    case context
}

struct AssetConfig: Identifiable, Codable, Hashable, Sendable {
    let symbol: String
    let displayName: String
    let assetClass: AssetClass
    let role: AssetRole
    let timezone: String
    let modelGroup: String
    let optionsEnabled: Bool
    let dataSymbol: String?

    var id: String { symbol }
    var providerSymbol: String { dataSymbol ?? symbol }
}

struct MarketBar: Codable, Hashable, Identifiable, Sendable {
    let symbol: String
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    let timeframe: String
    let source: String

    var id: String {
        "\(symbol)|\(timeframe)|\(timestamp.timeIntervalSince1970)"
    }
}

struct ProviderStatus: Equatable {
    var isLoading = false
    var message = "Ready"
    var lastRefresh: Date?
}

enum ProviderAvailability: String, Codable, Sendable {
    case unknown
    case checking
    case available
    case unavailable
    case restricted
    case rateLimited = "rate_limited"
    case error
}

struct AssetValidationState: Codable, Equatable, Sendable {
    let availability: ProviderAvailability
    let message: String
    let checkedAt: Date?
    var retryAfterSeconds: Double? = nil

    static let unknown = AssetValidationState(
        availability: .unknown,
        message: "Not validated yet.",
        checkedAt: nil
    )

    static let checking = AssetValidationState(
        availability: .checking,
        message: "Checking…",
        checkedAt: nil
    )

    var isStable: Bool {
        availability == .available
        || availability == .restricted
        || availability == .unavailable
    }
}

enum MarketDataError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case badHTTPStatus(Int)
    case rateLimited(message: String, retryAfter: TimeInterval?)
    case requestTimedOut(seconds: Int)
    case provider(String)
    case decoding(String)
    case invalidTimezone(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Twelve Data API key in Settings."
        case .invalidURL:
            return "Could not construct the market-data request."
        case .badHTTPStatus(let code):
            return "Market-data server returned HTTP \(code)."
        case .rateLimited(let message, let retryAfter):
            if let retryAfter {
                return "Rate limited: \(message) Retry after about \(Int(retryAfter))s."
            }
            return "Rate limited: \(message)"
        case .requestTimedOut(let seconds):
            return "Market-data request timed out after \(seconds)s."
        case .provider(let message):
            return message
        case .decoding(let message):
            return "Could not decode market data: \(message)"
        case .invalidTimezone(let value):
            return "Invalid timezone returned by provider: \(value)"
        case .noData:
            return "No bars were returned."
        }
    }
}
