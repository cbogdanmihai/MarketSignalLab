import Foundation

struct DiagnosticEvent: Codable, Sendable {
    let timestamp: Date
    let level: String
    let message: String
}

struct AssetDiagnosticSnapshot: Codable, Sendable {
    let symbol: String
    let providerSymbol: String
    let role: String
    let availability: String
    let validationMessage: String
    let checkedAt: Date?
}

struct DiagnosticsSnapshot: Codable, Sendable {
    let generatedAt: Date
    let appVersion: String
    let buildVersion: String
    let provider: String
    let selectedSymbol: String?
    let selectedStoredBars: Int
    let selectedEarliestBar: Date?
    let selectedLatestBar: Date?
    let selectedLatestClose: Double?
    let systemMessage: String

    let historicalIsRunning: Bool
    let historicalCompletedChunks: Int
    let historicalTotalChunks: Int
    let historicalBarsReceived: Int
    let historicalMessage: String

    let availableCount: Int
    let restrictedCount: Int
    let unavailableCount: Int
    let rateLimitedCount: Int

    let assets: [AssetDiagnosticSnapshot]
    let events: [DiagnosticEvent]
}
