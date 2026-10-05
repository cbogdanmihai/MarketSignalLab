import Foundation

protocol BarRepository: Sendable {
    func save(_ bars: [MarketBar]) async throws
    func load(symbol: String, timeframe: String) async throws -> [MarketBar]
}

actor JSONBarRepository: BarRepository {
    private let rootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        rootURL = base.appendingPathComponent(
            "MarketSignalLab/Bars",
            isDirectory: true
        )

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ bars: [MarketBar]) async throws {
        guard let first = bars.first else { return }

        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        let url = fileURL(
            symbol: first.symbol,
            timeframe: first.timeframe
        )

        let existing = (try? loadFromDisk(url)) ?? []

        var merged: [String: MarketBar] = [:]

        for bar in existing + bars {
            merged[bar.id] = bar
        }

        let ordered = merged.values.sorted {
            $0.timestamp < $1.timestamp
        }

        let data = try encoder.encode(ordered)
        try data.write(to: url, options: [.atomic])
    }

    func load(
        symbol: String,
        timeframe: String
    ) async throws -> [MarketBar] {
        let url = fileURL(
            symbol: symbol,
            timeframe: timeframe
        )

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        return try loadFromDisk(url)
    }

    private func loadFromDisk(
        _ url: URL
    ) throws -> [MarketBar] {
        let data = try Data(contentsOf: url)

        return try decoder.decode(
            [MarketBar].self,
            from: data
        )
    }

    private func fileURL(
        symbol: String,
        timeframe: String
    ) -> URL {
        let safeSymbol = symbol
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        return rootURL.appendingPathComponent(
            "\(safeSymbol)_\(timeframe).json"
        )
    }
}
