import SwiftUI
import Charts

enum ProfessionalChartStyle: String, CaseIterable, Identifiable {
    case candles = "Candles"
    case line = "Line"

    var id: String {
        rawValue
    }
}

enum ProfessionalChartInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 1
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60

    var id: Int {
        rawValue
    }

    var label: String {
        switch self {
        case .oneMinute:
            return "1m"
        case .fiveMinutes:
            return "5m"
        case .fifteenMinutes:
            return "15m"
        case .thirtyMinutes:
            return "30m"
        case .oneHour:
            return "1h"
        }
    }
}

enum ProfessionalChartRange: String, CaseIterable, Identifiable {
    case oneDay = "1D"
    case fiveDays = "5D"
    case oneMonth = "1M"
    case all = "ALL"

    var id: String {
        rawValue
    }

    var sessions: Int? {
        switch self {
        case .oneDay:
            return 1
        case .fiveDays:
            return 5
        case .oneMonth:
            return 22
        case .all:
            return nil
        }
    }
}

private struct ProfessionalChartPoint: Identifiable {
    let bar: MarketBar
    let sma20: Double?
    let sma50: Double?
    let vwap: Double?

    var id: String {
        bar.id
    }
}

struct ProfessionalChartView: View {
    let asset: AssetConfig
    let bars: [MarketBar]

    @State
    private var chartStyle: ProfessionalChartStyle = .candles

    @State
    private var interval: ProfessionalChartInterval = .fiveMinutes

    @State
    private var range: ProfessionalChartRange = .oneDay

    @State
    private var showSMA20 = true

    @State
    private var showSMA50 = false

    @State
    private var showVWAP = true

    @State
    private var showVolume = true

    @State
    private var selectedTimestamp: Date?

    private var aggregatedBars: [MarketBar] {
        aggregate(
            bars: bars,
            minutes: interval.rawValue
        )
    }

    private var rangedBars: [MarketBar] {
        guard let sessions = range.sessions else {
            return aggregatedBars
        }

        let barsPerSession: Int

        if asset.assetClass == .crypto {
            barsPerSession = max(
                1,
                1440 / interval.rawValue
            )
        } else {
            barsPerSession = max(
                1,
                390 / interval.rawValue
            )
        }

        let count = max(
            barsPerSession * sessions,
            1
        )

        return Array(
            aggregatedBars.suffix(count)
        )
    }

    private var points: [ProfessionalChartPoint] {
        buildPoints(
            bars: rangedBars
        )
    }

    private var selectedPoint: ProfessionalChartPoint? {
        guard let selectedTimestamp else {
            return nil
        }

        return points.min {
            abs(
                $0.bar.timestamp.timeIntervalSince(
                    selectedTimestamp
                )
            )
            <
            abs(
                $1.bar.timestamp.timeIntervalSince(
                    selectedTimestamp
                )
            )
        }
    }

    private var yDomain: ClosedRange<Double> {
        guard !rangedBars.isEmpty else {
            return 0...1
        }

        let low = rangedBars.map(\.low).min() ?? 0
        let high = rangedBars.map(\.high).max() ?? 1

        let rawRange = max(
            high - low,
            max(
                abs(high) * 0.0005,
                0.01
            )
        )

        let padding = rawRange * 0.12

        return (low - padding)...(high + padding)
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            toolbar

            if let selectedPoint {
                selectedBarStrip(
                    selectedPoint
                )
            } else if let last = rangedBars.last {
                liveBarStrip(
                    last
                )
            }

            if rangedBars.count >= 2 {
                priceChart

                if showVolume {
                    volumeChart
                }

            } else {
                ContentUnavailableView(
                    "No chart data",
                    systemImage: "chart.xyaxis.line",
                    description: Text(
                        "Fetch or download local market data for \(asset.symbol)."
                    )
                )
                .frame(height: 360)
            }
        }
    }

    private var toolbar: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack(spacing: 8) {
                ForEach(
                    ProfessionalChartInterval.allCases
                ) { item in
                    Button(item.label) {
                        interval = item
                        selectedTimestamp = nil
                    }
                    .buttonStyle(
                        .bordered
                    )
                    .controlSize(.small)
                    .tint(
                        interval == item
                        ? .accentColor
                        : .secondary
                    )
                }

                Divider()
                    .frame(height: 20)

                Picker(
                    "Style",
                    selection: $chartStyle
                ) {
                    ForEach(
                        ProfessionalChartStyle.allCases
                    ) { style in
                        Text(style.rawValue)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer()

                Menu {
                    Toggle(
                        "SMA 20",
                        isOn: $showSMA20
                    )

                    Toggle(
                        "SMA 50",
                        isOn: $showSMA50
                    )

                    Toggle(
                        "VWAP",
                        isOn: $showVWAP
                    )

                    Toggle(
                        "Volume",
                        isOn: $showVolume
                    )
                } label: {
                    Label(
                        "Indicators",
                        systemImage: "waveform.path.ecg"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                ForEach(
                    ProfessionalChartRange.allCases
                ) { item in
                    Button(item.rawValue) {
                        range = item
                        selectedTimestamp = nil
                    }
                    .buttonStyle(.borderless)
                    .font(
                        .caption.weight(
                            range == item
                            ? .semibold
                            : .regular
                        )
                    )
                    .foregroundStyle(
                        range == item
                        ? Color.accentColor
                        : Color.secondary
                    )
                }

                Spacer()

                Text(
                    "\(rangedBars.count) bars · \(interval.label)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var priceChart: some View {
        Chart {
            ForEach(points) { point in
                switch chartStyle {
                case .candles:
                    RuleMark(
                        x: .value(
                            "Time",
                            point.bar.timestamp
                        ),
                        yStart: .value(
                            "Low",
                            point.bar.low
                        ),
                        yEnd: .value(
                            "High",
                            point.bar.high
                        )
                    )
                    .foregroundStyle(
                        candleColor(
                            point.bar
                        )
                    )

                    RectangleMark(
                        x: .value(
                            "Time",
                            point.bar.timestamp
                        ),
                        yStart: .value(
                            "Body Low",
                            min(
                                point.bar.open,
                                point.bar.close
                            )
                        ),
                        yEnd: .value(
                            "Body High",
                            max(
                                point.bar.open,
                                point.bar.close
                            )
                        ),
                        width: .fixed(
                            candleWidth
                        )
                    )
                    .foregroundStyle(
                        candleColor(
                            point.bar
                        )
                    )

                case .line:
                    LineMark(
                        x: .value(
                            "Time",
                            point.bar.timestamp
                        ),
                        y: .value(
                            "Close",
                            point.bar.close
                        )
                    )
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.6
                        )
                    )
                }

                if showSMA20,
                   let sma20 = point.sma20 {

                    LineMark(
                        x: .value(
                            "Time",
                            point.bar.timestamp
                        ),
                        y: .value(
                            "SMA20",
                            sma20
                        ),
                        series: .value(
                            "Indicator",
                            "SMA20"
                        )
                    )
                    .foregroundStyle(
                        .orange
                    )
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.1
                        )
                    )
                }

                if showSMA50,
                   let sma50 = point.sma50 {

                    LineMark(
                        x: .value(
                            "Time",
                            point.bar.timestamp
                        ),
                        y: .value(
                            "SMA50",
                            sma50
                        ),
                        series: .value(
                            "Indicator",
                            "SMA50"
                        )
                    )
                    .foregroundStyle(
                        .purple
                    )
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.1
                        )
                    )
                }

                if showVWAP,
                   let vwap = point.vwap {

                    LineMark(
                        x: .value(
                            "Time",
                            point.bar.timestamp
                        ),
                        y: .value(
                            "VWAP",
                            vwap
                        ),
                        series: .value(
                            "Indicator",
                            "VWAP"
                        )
                    )
                    .foregroundStyle(
                        .blue
                    )
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.1,
                            dash: [4, 3]
                        )
                    )
                }
            }

            if let selectedPoint {
                RuleMark(
                    x: .value(
                        "Selected",
                        selectedPoint.bar.timestamp
                    )
                )
                .foregroundStyle(
                    .secondary.opacity(0.7)
                )
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 0.8,
                        dash: [3, 3]
                    )
                )

                RuleMark(
                    y: .value(
                        "Selected close",
                        selectedPoint.bar.close
                    )
                )
                .foregroundStyle(
                    .secondary.opacity(0.5)
                )
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 0.8,
                        dash: [3, 3]
                    )
                )
            }
        }
        .chartYScale(
            domain: yDomain
        )
        .chartXAxis {
            AxisMarks(
                values: .automatic(
                    desiredCount: 6
                )
            ) { value in
                AxisGridLine()
                    .foregroundStyle(
                        .secondary.opacity(0.12)
                    )

                AxisValueLabel(
                    format:
                        .dateTime
                        .month(.abbreviated)
                        .day()
                        .hour()
                        .minute()
                )
            }
        }
        .chartYAxis {
            AxisMarks(
                position: .trailing
            ) { _ in
                AxisGridLine()
                    .foregroundStyle(
                        .secondary.opacity(0.12)
                    )

                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(
                            minimumDistance: 0
                        )
                        .onChanged { value in
                            let plotFrame =
                                geometry[
                                    proxy.plotFrame!
                                ]

                            let x =
                                value.location.x
                                - plotFrame.origin.x

                            if let date: Date =
                                proxy.value(
                                    atX: x
                                ) {

                                selectedTimestamp =
                                    date
                            }
                        }
                        .onEnded { _ in
                            // Keep the last crosshair position,
                            // like a pinned inspection point.
                        }
                    )
            }
        }
        .frame(
            minHeight: 420
        )
    }

    private var volumeChart: some View {
        Chart(rangedBars) { bar in
            BarMark(
                x: .value(
                    "Time",
                    bar.timestamp
                ),
                y: .value(
                    "Volume",
                    bar.volume ?? 0
                )
            )
            .foregroundStyle(
                candleColor(bar)
                    .opacity(0.5)
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(
                position: .trailing,
                values: .automatic(
                    desiredCount: 2
                )
            ) {
                AxisValueLabel()
            }
        }
        .frame(height: 90)
    }

    private func liveBarStrip(
        _ bar: MarketBar
    ) -> some View {
        HStack(spacing: 16) {
            Text(
                asset.symbol
            )
            .font(.headline)

            ohlcLabel(
                "O",
                value: bar.open
            )

            ohlcLabel(
                "H",
                value: bar.high
            )

            ohlcLabel(
                "L",
                value: bar.low
            )

            ohlcLabel(
                "C",
                value: bar.close
            )

            if let volume = bar.volume {
                Text(
                    "V \(volume, format: .number.notation(.compactName))"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(
                bar.timestamp,
                format:
                    .dateTime
                    .month(.abbreviated)
                    .day()
                    .hour()
                    .minute()
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func selectedBarStrip(
        _ point: ProfessionalChartPoint
    ) -> some View {
        liveBarStrip(
            point.bar
        )
    }

    private func ohlcLabel(
        _ key: String,
        value: Double
    ) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .foregroundStyle(
                    .secondary
                )

            Text(
                value,
                format:
                    .number.precision(
                        .fractionLength(2)
                    )
            )
            .monospacedDigit()
        }
        .font(.caption)
    }

    private var candleWidth: CGFloat {
        switch interval {
        case .oneMinute:
            return 2.0
        case .fiveMinutes:
            return 3.0
        case .fifteenMinutes:
            return 4.0
        case .thirtyMinutes:
            return 5.0
        case .oneHour:
            return 6.0
        }
    }

    private func candleColor(
        _ bar: MarketBar
    ) -> Color {
        bar.close >= bar.open
        ? .green
        : .red
    }

    private func aggregate(
        bars: [MarketBar],
        minutes: Int
    ) -> [MarketBar] {
        guard minutes > 1 else {
            return bars.sorted {
                $0.timestamp < $1.timestamp
            }
        }

        let seconds = TimeInterval(
            minutes * 60
        )

        let ordered = bars.sorted {
            $0.timestamp < $1.timestamp
        }

        let grouped = Dictionary(
            grouping: ordered
        ) { bar in
            floor(
                bar.timestamp.timeIntervalSince1970
                / seconds
            )
        }

        return grouped.keys.sorted().compactMap {
            bucket in

            guard let group =
                    grouped[bucket]?.sorted(
                        by: {
                            $0.timestamp
                                < $1.timestamp
                        }
                    ),
                  let first = group.first,
                  let last = group.last
            else {
                return nil
            }

            let volume = group.compactMap {
                $0.volume
            }

            return MarketBar(
                symbol: first.symbol,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            bucket * seconds
                    ),
                open: first.open,
                high:
                    group.map(\.high).max()
                    ?? first.high,
                low:
                    group.map(\.low).min()
                    ?? first.low,
                close: last.close,
                volume:
                    volume.isEmpty
                    ? nil
                    : volume.reduce(0, +),
                timeframe:
                    "\(minutes)min",
                source: first.source
            )
        }
    }

    private func buildPoints(
        bars: [MarketBar]
    ) -> [ProfessionalChartPoint] {
        guard !bars.isEmpty else {
            return []
        }

        let timezone =
            TimeZone(
                identifier: asset.timezone
            )
            ?? TimeZone(secondsFromGMT: 0)!

        var calendar = Calendar(
            identifier: .gregorian
        )
        calendar.timeZone = timezone

        var result:
            [ProfessionalChartPoint] = []

        var cumulativePV = 0.0
        var cumulativeVolume = 0.0
        var currentSession:
            DateComponents?

        for index in bars.indices {
            let bar = bars[index]

            let session =
                calendar.dateComponents(
                    [.year, .month, .day],
                    from: bar.timestamp
                )

            if currentSession != session {
                currentSession = session
                cumulativePV = 0
                cumulativeVolume = 0
            }

            if let volume = bar.volume,
               volume > 0 {

                let typical =
                    (bar.high
                     + bar.low
                     + bar.close)
                    / 3

                cumulativePV +=
                    typical * volume

                cumulativeVolume +=
                    volume
            }

            let sma20 =
                rollingAverage(
                    bars: bars,
                    endIndex: index,
                    period: 20
                )

            let sma50 =
                rollingAverage(
                    bars: bars,
                    endIndex: index,
                    period: 50
                )

            let vwap =
                cumulativeVolume > 0
                ? cumulativePV
                    / cumulativeVolume
                : nil

            result.append(
                ProfessionalChartPoint(
                    bar: bar,
                    sma20: sma20,
                    sma50: sma50,
                    vwap: vwap
                )
            )
        }

        return result
    }

    private func rollingAverage(
        bars: [MarketBar],
        endIndex: Int,
        period: Int
    ) -> Double? {
        let start =
            endIndex - period + 1

        guard start >= 0 else {
            return nil
        }

        let values =
            bars[start...endIndex]
                .map {
                    $0.close
                }

        return values.reduce(
            0,
            +
        ) / Double(values.count)
    }
}
