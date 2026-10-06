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

    @Environment(\.terminalDensityScale)
    private var densityScale

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

    @State
    private var scrollPosition = Date()

    @State
    private var zoomLevel = 1.0

    @State
    private var inspectionMode = false

    private var aggregatedBars: [MarketBar] {
        aggregate(
            bars: bars,
            minutes: interval.rawValue
        )
    }

    private var chartBars: [MarketBar] {
        // Keep enough history loaded for horizontal scrolling without
        // asking Swift Charts to render an unbounded 1-minute archive.
        Array(
            aggregatedBars.suffix(5000)
        )
    }

    private var baseVisibleDuration: TimeInterval {
        let day: TimeInterval =
            24 * 60 * 60

        switch range {
        case .oneDay:
            return asset.assetClass == .crypto
            ? day
            : 8 * 60 * 60

        case .fiveDays:
            return 7 * day

        case .oneMonth:
            return 31 * day

        case .all:
            guard
                let first =
                    chartBars.first?.timestamp,
                let last =
                    chartBars.last?.timestamp
            else {
                return day
            }

            return max(
                last.timeIntervalSince(first),
                day
            )
        }
    }

    private var visibleDuration: TimeInterval {
        max(
            baseVisibleDuration
                / zoomLevel,
            TimeInterval(
                interval.rawValue * 60 * 3
            )
        )
    }

    private var visibleBarsForScale: [MarketBar] {
        let end =
            scrollPosition.addingTimeInterval(
                visibleDuration
            )

        let visible = chartBars.filter {
            $0.timestamp >= scrollPosition
            && $0.timestamp <= end
        }

        if !visible.isEmpty {
            return visible
        }

        return Array(
            chartBars.suffix(60)
        )
    }

    private var points: [ProfessionalChartPoint] {
        buildPoints(
            bars: chartBars
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
        guard !visibleBarsForScale.isEmpty else {
            return 0...1
        }

        let low =
            visibleBarsForScale.map(\.low).min()
            ?? 0

        let high =
            visibleBarsForScale.map(\.high).max()
            ?? 1

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
            } else if let last = chartBars.last {
                liveBarStrip(
                    last
                )
            }

            if chartBars.count >= 2 {
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
        .onAppear {
            scrollToLatest()
        }
        .onChange(
            of: bars.last?.timestamp
        ) { _, _ in
            scrollToLatest()
        }
        .onChange(
            of: zoomLevel
        ) { _, _ in
            clampScrollPosition()
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
                        scrollToLatest()
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
                .frame(
                    width: 180 * densityScale
                )

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

                Button {
                    inspectionMode.toggle()

                    if !inspectionMode {
                        selectedTimestamp = nil
                    }
                } label: {
                    Image(
                        systemName:
                            inspectionMode
                            ? "scope"
                            : "scope"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(
                    inspectionMode
                    ? .accentColor
                    : .secondary
                )
                .help(
                    inspectionMode
                    ? "Crosshair on"
                    : "Crosshair off"
                )
            }

            HStack(spacing: 8) {
                ForEach(
                    ProfessionalChartRange.allCases
                ) { item in
                    Button(item.rawValue) {
                        range = item
                        selectedTimestamp = nil
                        scrollToLatest()
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

                HStack(spacing: 4) {
                    Button {
                        zoomLevel = max(
                            0.5,
                            zoomLevel / 1.4
                        )
                    } label: {
                        Image(
                            systemName:
                                "minus.magnifyingglass"
                        )
                    }
                    .buttonStyle(.borderless)

                    Button {
                        zoomLevel = min(
                            4.0,
                            zoomLevel * 1.4
                        )
                    } label: {
                        Image(
                            systemName:
                                "plus.magnifyingglass"
                        )
                    }
                    .buttonStyle(.borderless)
                }

                Text(
                    "\(chartBars.count) loaded · \(interval.label) · drag to scroll"
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
        .chartScrollableAxes(
            .horizontal
        )
        .chartXVisibleDomain(
            length: visibleDuration
        )
        .chartScrollPosition(
            x: $scrollPosition
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
                if inspectionMode {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(
                            Rectangle()
                        )
                        .gesture(
                            DragGesture(
                                minimumDistance: 0
                            )
                            .onChanged { value in
                                guard let anchor =
                                        proxy.plotFrame
                                else {
                                    return
                                }

                                let plotFrame =
                                    geometry[anchor]

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
                        )

                } else {
                    Rectangle()
                        .fill(.clear)
                        .allowsHitTesting(
                            false
                        )
                }
            }
        }
        .frame(
            minHeight:
                420 * densityScale
        )
    }

    private var volumeChart: some View {
        Chart(chartBars) { bar in
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
        .chartScrollableAxes(
            .horizontal
        )
        .chartXVisibleDomain(
            length: visibleDuration
        )
        .chartScrollPosition(
            x: $scrollPosition
        )
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
        .frame(
            height:
                90 * densityScale
        )
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
            return 2.0 * densityScale
        case .fiveMinutes:
            return 3.0 * densityScale
        case .fifteenMinutes:
            return 4.0 * densityScale
        case .thirtyMinutes:
            return 5.0 * densityScale
        case .oneHour:
            return 6.0 * densityScale
        }
    }

    private func candleColor(
        _ bar: MarketBar
    ) -> Color {
        bar.close >= bar.open
        ? .green
        : .red
    }

    private func scrollToLatest() {
        guard
            let first =
                chartBars.first?.timestamp,
            let last =
                chartBars.last?.timestamp
        else {
            return
        }

        let candidate =
            last.addingTimeInterval(
                -visibleDuration
            )

        scrollPosition = max(
            first,
            candidate
        )
    }

    private func clampScrollPosition() {
        guard
            let first =
                chartBars.first?.timestamp,
            let last =
                chartBars.last?.timestamp
        else {
            return
        }

        let latestStart =
            max(
                first,
                last.addingTimeInterval(
                    -visibleDuration
                )
            )

        if scrollPosition < first {
            scrollPosition = first
        }

        if scrollPosition > latestStart {
            scrollPosition =
                latestStart
        }
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
