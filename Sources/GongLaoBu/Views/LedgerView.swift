import SwiftUI

struct LedgerView: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store

    private var groups: [CompletedTaskGroup] {
        completedGroups(from: filteredCompletedTasks)
    }

    private var stats: LedgerStats {
        store.ledgerStats()
    }

    private var filteredCompletedTasks: [TaskItem] {
        let query = appState.ledgerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedQuery = query.lowercased()
        let calendar = Calendar.current

        return store.tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            if !query.isEmpty, !task.title.lowercased().contains(lowercasedQuery) {
                return false
            }
            if !appState.ledgerDateFilter.contains(completedAt, calendar: calendar) {
                return false
            }
            if !appState.ledgerQuadrantFilter.matches(task.quadrant) {
                return false
            }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "功劳簿", subtitle: "已完成 \(stats.total) 件")

                StatsGrid(stats: stats)

                if groups.isEmpty {
                    EmptyStateView(title: store.tasks.contains(where: { $0.completedAt != nil }) ? "没有匹配记录" : "还没有完成记录", symbolName: "checklist")
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            CompletedGroupView(group: group)
                        }
                    }
                }
            }
            .padding(GLBTheme.pagePadding)
        }
    }

    private func completedGroups(from tasks: [TaskItem]) -> [CompletedTaskGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: tasks) { task in
            calendar.startOfDay(for: task.completedAt ?? task.plannedDate)
        }

        return grouped.keys.sorted(by: >).map { day in
            let tasks = (grouped[day] ?? []).sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
            return CompletedTaskGroup(date: day, tasks: tasks)
        }
    }
}

private struct StatsGrid: View {
    var stats: LedgerStats

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: "今天", value: stats.today, color: .green)
            StatTile(title: "本周", value: stats.week, color: .blue)
            StatTile(title: "本月", value: stats.month, color: .orange)
            StatTile(title: "本年", value: stats.year, color: GLBTheme.gold)
            StatTile(title: "总计", value: stats.total, color: GLBTheme.red)
        }
    }
}

private struct StatTile: View {
    var title: String
    var value: Int
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: GLBTheme.radius)
                .stroke(color.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct CompletedGroupView: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store
    var group: CompletedTaskGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: "checkmark.seal.fill", color: .green)
                Text(group.date.glbShortDayTitle)
                    .font(.title3.weight(.semibold))

                Spacer()

                Text("\(group.tasks.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.green)
                    .monospacedDigit()
            }

            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.green.opacity(0.22))
                    .frame(width: 2)
                    .padding(.vertical, 6)

                LazyVStack(spacing: 9) {
                    ForEach(group.tasks) { task in
                        TaskRowView(
                            task: task,
                            isSelected: appState.selectedTaskID == task.id,
                            onSelect: { appState.selectTask(id: task.id) },
                            onToggle: { store.toggleCompletion(task) },
                            onRename: { store.rename(task, to: $0) },
                            onDelete: { delete(task) }
                        )
                    }
                }
            }
        }
    }

    private func delete(_ task: TaskItem) {
        if appState.selectedTaskID == task.id {
            appState.selectTask(id: nil)
        }
        store.delete(task)
    }
}
