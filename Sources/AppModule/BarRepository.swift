import Foundation

struct BarStorageStats: Equatable, Sendable {
    let count: Int
    let earliest: Date?
    let latest: Date?
    let latestClose: Double?
    let previousClose: Double?

    static let empty = BarStorageStats(
        count: 0,
        earliest: nil,
        latest: nil,
        latestClose: nil,
        previousClose: nil
    )

    static func from(
        bars: [MarketBar]
    ) -> BarStorageStats {
        BarStorageStats(
            count: bars.count,
            earliest: bars.first?.timestamp,
            latest: bars.last?.timestamp,
            latestClose: bars.last?.close,
            previousClose:
                bars.count >= 2
                ? bars[bars.count - 2].close
                : nil
        )
    }

    var latestChangePct: Double? {
        guard
            let latestClose,
            let previousClose,
            previousClose != 0
        else {
            return nil
        }

        return latestClose / previousClose - 1
    }
}

protocol BarRepository: Sendable {
    func save(_ bars: [MarketBar]) async throws

    func load(
        symbol: String,
        timeframe: String
    ) async throws -> [MarketBar]

    func load(
        symbol: String,
        timeframe: String,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> [MarketBar]

    func stats(
        symbol: String,
        timeframe: String
    ) async throws -> BarStorageStats
}

actor PartitionedJSONBarRepository: BarRepository {
    private let rootURL: URL
    private let legacyRootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        rootURL = base.appendingPathComponent(
            "MarketSignalLab/BarsV2",
            isDirectory: true
        )

        legacyRootURL = base.appendingPathComponent(
            "MarketSignalLab/Bars",
            isDirectory: true
        )

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ bars: [MarketBar]) async throws {
        guard !bars.isEmpty else {
            return
        }

        let grouped = Dictionary(
            grouping: bars,
            by: { partitionKey(for: $0.timestamp) }
        )

        for (partition, partitionBars) in grouped {
            guard let first = partitionBars.first else {
                continue
            }

            let directory = directoryURL(
                symbol: first.symbol,
                timeframe: first.timeframe
            )

            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let url = directory.appendingPathComponent(
                "\(partition).json"
            )

            let existing = (try? loadFromDisk(url)) ?? []
            var merged: [String: MarketBar] = [:]

            for bar in existing + partitionBars {
                merged[bar.id] = bar
            }

            let ordered = merged.values.sorted {
                $0.timestamp < $1.timestamp
            }

            let data = try encoder.encode(ordered)
            try data.write(
                to: url,
                options: [.atomic]
            )
        }
    }

    func load(
        symbol: String,
        timeframe: String
    ) async throws -> [MarketBar] {
        try await migrateLegacyIfNeeded(
            symbol: symbol,
            timeframe: timeframe
        )

        return try loadPartitions(
            symbol: symbol,
            timeframe: timeframe,
            from: nil,
            to: nil
        )
    }

    func load(
        symbol: String,
        timeframe: String,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> [MarketBar] {
        try await migrateLegacyIfNeeded(
            symbol: symbol,
            timeframe: timeframe
        )

        return try loadPartitions(
            symbol: symbol,
            timeframe: timeframe,
            from: startDate,
            to: endDate
        )
    }

    func stats(
        symbol: String,
        timeframe: String
    ) async throws -> BarStorageStats {
        let bars = try await load(
            symbol: symbol,
            timeframe: timeframe
        )

        return BarStorageStats.from(
            bars: bars
        )
    }

    private func loadPartitions(
        symbol: String,
        timeframe: String,
        from startDate: Date?,
        to endDate: Date?
    ) throws -> [MarketBar] {
        let directory = directoryURL(
            symbol: symbol,
            timeframe: timeframe
        )

        guard FileManager.default.fileExists(
            atPath: directory.path
        ) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var result: [MarketBar] = []

        for url in urls {
            let partitionBars = try loadFromDisk(url)

            result.append(
                contentsOf: partitionBars.filter { bar in
                    if let startDate,
                       bar.timestamp < startDate {
                        return false
                    }

                    if let endDate,
                       bar.timestamp > endDate {
                        return false
                    }

                    return true
                }
            )
        }

        return result.sorted {
            $0.timestamp < $1.timestamp
        }
    }

    private func migrateLegacyIfNeeded(
        symbol: String,
        timeframe: String
    ) async throws {
        let directory = directoryURL(
            symbol: symbol,
            timeframe: timeframe
        )

        if FileManager.default.fileExists(
            atPath: directory.path
        ) {
            return
        }

        let legacyURL = legacyFileURL(
            symbol: symbol,
            timeframe: timeframe
        )

        guard FileManager.default.fileExists(
            atPath: legacyURL.path
        ) else {
            return
        }

        let legacyBars = try loadFromDisk(
            legacyURL
        )

        try await save(legacyBars)
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

    private func directoryURL(
        symbol: String,
        timeframe: String
    ) -> URL {
        rootURL
            .appendingPathComponent(
                safe(symbol),
                isDirectory: true
            )
            .appendingPathComponent(
                safe(timeframe),
                isDirectory: true
            )
    }

    private func legacyFileURL(
        symbol: String,
        timeframe: String
    ) -> URL {
        legacyRootURL.appendingPathComponent(
            "\(safe(symbol))_\(safe(timeframe)).json"
        )
    }

    private func safe(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: "/",
                with: "_"
            )
            .replacingOccurrences(
                of: ":",
                with: "_"
            )
    }

    private func partitionKey(
        for date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(
            identifier: .gregorian
        )
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        formatter.timeZone = TimeZone(
            secondsFromGMT: 0
        )
        formatter.dateFormat = "yyyy-MM"

        return formatter.string(
            from: date
        )
    }
}
