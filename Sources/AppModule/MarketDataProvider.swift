import Foundation

protocol MarketDataProvider: Sendable {
    var providerName: String { get }

    func bars(
        for asset: AssetConfig,
        interval: String,
        outputSize: Int
    ) async throws -> [MarketBar]
}
