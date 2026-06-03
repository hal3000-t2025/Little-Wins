import SwiftUI

struct StatisticsView: View {
    @Environment(TaskStore.self) private var store
    @State private var range: StatsRange = .sevenDays

    private var dailyCounts: [DailyCompletionCount] {
        store.dailyCompletionCounts(days: range.days)
    }

    private var quadrantCounts: [QuadrantCompletionCount] {
        store.quadrantCompletionCounts(in: range.interval)
    }

    private var delayedTasks: [DelaySummary] {
        store.delayedTaskSummaries()
    }

    private var totalInRange: Int {
        dailyCounts.map(\.count).reduce(0, +)
    }

    private var stats: LedgerStats {
        store.ledgerStats()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "统计", subtitle: "最近 \(range.days) 天完成 \(totalInRange) 件") {
                    Picker("范围", selection: $range) {
                        ForEach(StatsRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                PraisePanel(stats: stats, totalInRange: totalInRange, range: range)

                CompletionTrendView(counts: dailyCounts)

                HStack(alignment: .top, spacing: 14) {
                    QuadrantStatsPanel(counts: quadrantCounts)
                    DelayStatsPanel(items: delayedTasks)
                }
            }
            .padding(GLBTheme.pagePadding)
        }
    }
}

private struct PraisePanel: View {
    var stats: LedgerStats
    var totalInRange: Int
    var range: StatsRange

    private var title: String {
        if stats.today >= 10 {
            return "你太棒了，今天完成了 \(stats.today) 件事，你简直是个天才！"
        }
        if stats.today >= 5 {
            return "今天完成了 \(stats.today) 件事，执行力很猛。"
        }
        if stats.today > 0 {
            return "今天已经完成 \(stats.today) 件事，节奏不错。"
        }
        if stats.week > 0 {
            return "今天还没记录完成，但本周已经完成 \(stats.week) 件，继续推进。"
        }
        return "今天还没开始，先完成一件小事就能启动。"
    }

    private var subtitle: String {
        if stats.total == 0 {
            return "功劳簿会记住你做成的每一件事。"
        }
        return "\(range.title) 内完成 \(totalInRange) 件，功劳簿累计 \(stats.total) 件。"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(GLBTheme.gold)
                .frame(width: 46, height: 46)
                .background(GLBTheme.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: GLBTheme.radius))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(GLBTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: GLBTheme.radius)
                .stroke(GLBTheme.gold.opacity(0.28), lineWidth: 1)
        }
    }
}

private enum StatsRange: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30
    case year = 365

    var id: Int { rawValue }
    var days: Int { rawValue }

    var title: String {
        switch self {
        case .sevenDays:
            "7 天"
        case .thirtyDays:
            "30 天"
        case .year:
            "365 天"
        }
    }

    var interval: DateInterval? {
        let calendar = Calendar.current
        let end = Date.now
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: end)) ?? end
        return DateInterval(start: start, end: end)
    }
}

private struct CompletionTrendView: View {
    var counts: [DailyCompletionCount]

    private var maxCount: Int {
        max(counts.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        PanelSurface(tint: .green) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(systemName: "chart.bar.xaxis", color: .green)
                    Text("完成趋势")
                        .font(.headline)
                    Spacer()
                }

                GeometryReader { proxy in
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(counts) { item in
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.count == 0 ? Color.secondary.opacity(0.16) : Color.green)
                                    .frame(height: barHeight(for: item.count, maxHeight: proxy.size.height - 34))

                                Text("\(Calendar.current.component(.day, from: item.date))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(height: 18)
                            }
                            .frame(maxWidth: .infinity)
                            .help("\(item.date.glbShortDayTitle)：\(item.count)")
                        }
                    }
                }
                .frame(height: 190)
            }
        }
    }

    private func barHeight(for count: Int, maxHeight: CGFloat) -> CGFloat {
        guard count > 0 else { return 6 }
        return max(10, maxHeight * CGFloat(count) / CGFloat(maxCount))
    }
}

private struct QuadrantStatsPanel: View {
    var counts: [QuadrantCompletionCount]

    private var total: Int {
        counts.map(\.count).reduce(0, +)
    }

    var body: some View {
        PanelSurface(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(systemName: "square.grid.2x2", color: .blue)
                    Text("象限完成占比")
                        .font(.headline)
                    Spacer()
                }

                if total == 0 {
                    EmptyStateView(title: "暂无数据", symbolName: "chart.pie")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(counts) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(color(for: item.quadrant))
                                .frame(width: 10, height: 10)

                            Text(item.title)
                                .frame(width: 92, alignment: .leading)

                            ProgressView(value: Double(item.count), total: Double(max(total, 1)))
                                .tint(color(for: item.quadrant))

                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 30, alignment: .trailing)
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func color(for quadrant: TaskQuadrant?) -> Color {
        quadrant?.tintColor ?? .secondary
    }
}

private struct DelayStatsPanel: View {
    var items: [DelaySummary]

    var body: some View {
        PanelSurface(tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(systemName: "clock.badge.exclamationmark", color: .purple)
                    Text("延期最多")
                        .font(.headline)
                    Spacer()
                }

                if items.isEmpty {
                    EmptyStateView(title: "暂无延期", symbolName: "checkmark.circle")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Text(item.task.title)
                                .lineLimit(1)

                            Spacer()

                            BadgeView(text: "\(item.count) 次", color: item.count >= 3 ? .red : .purple)
                        }
                        .font(.callout)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
