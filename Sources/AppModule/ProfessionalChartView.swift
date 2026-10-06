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

    var recommendedRange: ProfessionalChartRange {
        switch self {
        case .oneMinute,
             .fiveMinutes:
            return .oneDay

        case .fifteenMinutes,
             .thirtyMinutes:
            return .fiveDays

        case .oneHour:
            return .oneMonth
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
}

private struct ProfessionalChartPoint: Identifiable {
    let index: Int
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
    private var selectedIndex: Int?

    @State
    private var scrollPosition = 0.0

    @State
    private var zoomLevel = 1.0

    @State
    private var pinchBaseZoom = 1.0

    @State
    private var inspectionMode = false

    private var aggregatedBars: [MarketBar] {
        aggregate(
            bars: bars,
            minutes: interval.rawValue
        )
    }

    private var chartBars: [MarketBar] {
        // Current research histories are small enough to keep the complete
        // aggregated series in memory. A generous cap protects Swift Charts
        // from accidental multi-year 1-minute archives.
        Array(
            aggregatedBars.suffix(20_000)
        )
    }

    private var baseVisibleBarCount: Int {
        guard !chartBars.isEmpty else {
            return 1
        }

        let sessionMinutes =
            asset.assetClass == .crypto
            ? 1440
            : 390

        let barsPerSession = max(
            1,
            Int(
                ceil(
                    Double(sessionMinutes)
                    / Double(interval.rawValue)
                )
            )
        )

        let requested: Int

        switch range {
        case .oneDay:
            requested = barsPerSession

        case .fiveDays:
            requested =
                barsPerSession * 5

        case .oneMonth:
            requested =
                barsPerSession * 22

        case .all:
            requested =
                chartBars.count
        }

        return min(
            max(requested, 3),
            chartBars.count
        )
    }

    private func visibleBarCount(
        for zoom: Double
    ) -> Int {
        guard !chartBars.isEmpty else {
            return 1
        }

        let count = Int(
            round(
                Double(baseVisibleBarCount)
                / zoom
            )
        )

        return min(
            max(count, 3),
            chartBars.count
        )
    }

    private var visibleBarCount: Int {
        visibleBarCount(
            for: zoomLevel
        )
    }

    private var visibleStartIndex: Int {
        let maximumStart = max(
            0,
            chartBars.count
                - visibleBarCount
        )

        return min(
            max(
                Int(
                    floor(scrollPosition)
                ),
                0
            ),
            maximumStart
        )
    }

    private var visibleEndIndex: Int {
        min(
            chartBars.count - 1,
            visibleStartIndex
                + visibleBarCount
                - 1
        )
    }

    private var visibleBarsForScale: [MarketBar] {
        guard
            !chartBars.isEmpty,
            visibleStartIndex
                <= visibleEndIndex
        else {
            return []
        }

        let range =
            visibleStartIndex...visibleEndIndex

        return Array(
            chartBars[range]
        )
    }

    private var points: [ProfessionalChartPoint] {
        buildPoints(
            bars: chartBars
        )
    }

    private var selectedPoint: ProfessionalChartPoint? {
        guard
            let selectedIndex,
            points.indices.contains(
                selectedIndex
            )
        else {
            return nil
        }

        return points[
            selectedIndex
        ]
    }

    private var yDomain: ClosedRange<Double> {
        guard !visibleBarsForScale.isEmpty else {
            return 0...1
        }

        let low =
            visibleBarsForScale
                .map(\.low)
                .min()
            ?? 0

        let high =
            visibleBarsForScale
                .map(\.high)
                .max()
            ?? 1

        let rawRange = max(
            high - low,
            max(
                abs(high) * 0.0005,
                0.01
            )
        )

        let padding =
            rawRange * 0.12

        return (low - padding)
            ...(high + padding)
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

            } else if let last =
                chartBars.last {

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
                    systemImage:
                        "chart.xyaxis.line",
                    description: Text(
                        "Fetch or download local market data for \(asset.symbol)."
                    )
                )
                .frame(height: 360)
            }
        }
        .onAppear {
            applyRecommendedViewport(
                for: interval
            )
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
                    ProfessionalChartInterval
                        .allCases
                ) { item in
                    Button(item.label) {
                        applyRecommendedViewport(
                            for: item
                        )
                    }
                    .buttonStyle(.bordered)
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
                        ProfessionalChartStyle
                            .allCases
                    ) { style in
                        Text(style.rawValue)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(
                    width:
                        180 * densityScale
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
                        systemImage:
                            "waveform.path.ecg"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    inspectionMode.toggle()

                    if !inspectionMode {
                        selectedIndex = nil
                    }
                } label: {
                    Image(
                        systemName: "scope"
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
                    ProfessionalChartRange
                        .allCases
                ) { item in
                    Button(item.rawValue) {
                        range = item
                        zoomLevel = 1
                        pinchBaseZoom = 1
                        selectedIndex = nil
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
                        setZoom(
                            zoomLevel / 1.35
                        )
                    } label: {
                        Image(
                            systemName:
                                "minus.magnifyingglass"
                        )
                    }
                    .buttonStyle(.borderless)

                    Button {
                        setZoom(
                            zoomLevel * 1.35
                        )
                    } label: {
                        Image(
                            systemName:
                                "plus.magnifyingglass"
                        )
                    }
                    .buttonStyle(.borderless)

                    Button {
                        zoomLevel = 1
                        pinchBaseZoom = 1
                        scrollToLatest()
                    } label: {
                        Image(
                            systemName:
                                "arrow.left.and.right"
                        )
                    }
                    .buttonStyle(.borderless)
                    .help(
                        "Fit selected range"
                    )

                    Button {
                        scrollToLatest()
                    } label: {
                        Image(
                            systemName:
                                "forward.end.fill"
                        )
                    }
                    .buttonStyle(.borderless)
                    .help(
                        "Jump to latest"
                    )
                }

                Text(
                    "\(visibleBarCount) visible / \(chartBars.count) loaded · \(interval.label)"
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
                            "Bar",
                            Double(point.index)
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
                            "Bar",
                            Double(point.index)
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
                            "Bar",
                            Double(point.index)
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
                   let sma20 =
                    point.sma20 {

                    LineMark(
                        x: .value(
                            "Bar",
                            Double(point.index)
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
                    .foregroundStyle(.orange)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.1
                        )
                    )
                }

                if showSMA50,
                   let sma50 =
                    point.sma50 {

                    LineMark(
                        x: .value(
                            "Bar",
                            Double(point.index)
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
                    .foregroundStyle(.purple)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.1
                        )
                    )
                }

                if showVWAP,
                   let vwap =
                    point.vwap {

                    LineMark(
                        x: .value(
                            "Bar",
                            Double(point.index)
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
                    .foregroundStyle(.blue)
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
                        Double(
                            selectedPoint.index
                        )
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
            length:
                Double(
                    visibleBarCount
                )
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
                        .secondary
                            .opacity(0.12)
                    )

                AxisValueLabel {
                    if let raw =
                        value.as(
                            Double.self
                        ) {

                        Text(
                            axisLabel(
                                for:
                                    Int(
                                        round(raw)
                                    )
                            )
                        )
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(
                position: .trailing
            ) { _ in
                AxisGridLine()
                    .foregroundStyle(
                        .secondary
                            .opacity(0.12)
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

                                if let raw:
                                    Double =
                                    proxy.value(
                                        atX: x
                                    ) {

                                    selectedIndex =
                                        nearestIndex(
                                            raw
                                        )
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
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    guard !inspectionMode else {
                        return
                    }

                    setZoom(
                        pinchBaseZoom
                            * value
                    )
                }
                .onEnded { _ in
                    pinchBaseZoom =
                        zoomLevel
                }
        )
        .frame(
            minHeight:
                420 * densityScale
        )
    }

    private var volumeChart: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value(
                        "Bar",
                        Double(point.index)
                    ),
                    y: .value(
                        "Volume",
                        point.bar.volume ?? 0
                    )
                )
                .foregroundStyle(
                    candleColor(
                        point.bar
                    )
                    .opacity(0.5)
                )
            }
        }
        .chartScrollableAxes(
            .horizontal
        )
        .chartXVisibleDomain(
            length:
                Double(
                    visibleBarCount
                )
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
            Text(asset.symbol)
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

            if let volume =
                bar.volume {

                Text(
                    "V \(volume, format: .number.notation(.compactName))"
                )
                .font(
                    .caption
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
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
            .font(
                .caption
                    .monospacedDigit()
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func selectedBarStrip(
        _ point:
            ProfessionalChartPoint
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
        let approximatePlotWidth =
            900 * densityScale

        let width =
            approximatePlotWidth
            / CGFloat(
                max(
                    visibleBarCount,
                    1
                )
            )

        return min(
            max(
                width * 0.62,
                1.0
            ),
            10.0
        )
    }

    private func candleColor(
        _ bar: MarketBar
    ) -> Color {
        bar.close >= bar.open
        ? .green
        : .red
    }

    private func applyRecommendedViewport(
        for newInterval:
            ProfessionalChartInterval
    ) {
        interval = newInterval
        range =
            newInterval.recommendedRange

        zoomLevel = 1
        pinchBaseZoom = 1
        selectedIndex = nil

        DispatchQueue.main.async {
            scrollToLatest()
        }
    }

    private func setZoom(
        _ requestedZoom: Double
    ) {
        guard !chartBars.isEmpty else {
            return
        }

        let oldCount =
            visibleBarCount

        let oldCenter =
            scrollPosition
            + Double(oldCount) / 2

        let clampedZoom = min(
            max(
                requestedZoom,
                0.35
            ),
            8.0
        )

        let newCount =
            visibleBarCount(
                for: clampedZoom
            )

        zoomLevel =
            clampedZoom

        let maximumStart =
            max(
                0,
                chartBars.count
                    - newCount
            )

        scrollPosition = min(
            max(
                oldCenter
                - Double(newCount) / 2,
                0
            ),
            Double(maximumStart)
        )
    }

    private func scrollToLatest() {
        let maximumStart = max(
            0,
            chartBars.count
                - visibleBarCount
        )

        scrollPosition =
            Double(maximumStart)
    }

    private func clampScrollPosition() {
        let maximumStart = max(
            0,
            chartBars.count
                - visibleBarCount
        )

        scrollPosition = min(
            max(
                scrollPosition,
                0
            ),
            Double(maximumStart)
        )
    }

    private func nearestIndex(
        _ raw: Double
    ) -> Int {
        guard !chartBars.isEmpty else {
            return 0
        }

        return min(
            max(
                Int(
                    round(raw)
                ),
                0
            ),
            chartBars.count - 1
        )
    }

    private func axisLabel(
        for index: Int
    ) -> String {
        guard chartBars.indices.contains(
            index
        ) else {
            return ""
        }

        let date =
            chartBars[index].timestamp

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier: "en_US_POSIX"
            )

        formatter.timeZone =
            TimeZone(
                identifier:
                    asset.timezone
            )
            ?? .current

        if range == .oneDay {
            formatter.dateFormat =
                "HH:mm"
        } else if range == .fiveDays {
            formatter.dateFormat =
                "EEE HH:mm"
        } else {
            formatter.dateFormat =
                "MMM d"
        }

        return formatter.string(
            from: date
        )
    }

    private func aggregate(
        bars: [MarketBar],
        minutes: Int
    ) -> [MarketBar] {
        guard minutes > 1 else {
            return bars.sorted {
                $0.timestamp
                    < $1.timestamp
            }
        }

        let seconds = TimeInterval(
            minutes * 60
        )

        let ordered = bars.sorted {
            $0.timestamp
                < $1.timestamp
        }

        let grouped = Dictionary(
            grouping: ordered
        ) { bar in
            floor(
                bar.timestamp
                    .timeIntervalSince1970
                / seconds
            )
        }

        return grouped.keys
            .sorted()
            .compactMap { bucket in
                guard
                    let group =
                        grouped[bucket]?
                        .sorted(
                            by: {
                                $0.timestamp
                                    < $1.timestamp
                            }
                        ),
                    let first =
                        group.first,
                    let last =
                        group.last
                else {
                    return nil
                }

                let volume =
                    group.compactMap {
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
                        group.map(\.high)
                            .max()
                        ?? first.high,
                    low:
                        group.map(\.low)
                            .min()
                        ?? first.low,
                    close: last.close,
                    volume:
                        volume.isEmpty
                        ? nil
                        : volume.reduce(
                            0,
                            +
                        ),
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
                identifier:
                    asset.timezone
            )
            ?? TimeZone(
                secondsFromGMT: 0
            )!

        var calendar =
            Calendar(
                identifier: .gregorian
            )

        calendar.timeZone =
            timezone

        var result:
            [ProfessionalChartPoint] = []

        var cumulativePV = 0.0
        var cumulativeVolume = 0.0

        var currentSession:
            DateComponents?

        for index in bars.indices {
            let bar =
                bars[index]

            let session =
                calendar.dateComponents(
                    [.year, .month, .day],
                    from: bar.timestamp
                )

            if currentSession
                != session {

                currentSession =
                    session

                cumulativePV = 0
                cumulativeVolume = 0
            }

            if let volume =
                bar.volume,
               volume > 0 {

                let typical =
                    (
                        bar.high
                        + bar.low
                        + bar.close
                    )
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
                    index: index,
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
            bars[
                start...endIndex
            ]
            .map {
                $0.close
            }

        return values.reduce(
            0,
            +
        )
        / Double(values.count)
    }
}
