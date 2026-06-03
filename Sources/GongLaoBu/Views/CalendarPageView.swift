import SwiftUI

struct CalendarPageView: View {
    @Environment(TaskStore.self) private var store

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(minimum: 92), spacing: 0), count: 7)

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: store.selectedDate)?.start ?? calendar.startOfDay(for: store.selectedDate)
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.year().month(.wide))
    }

    private var monthTaskCount: Int {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else { return 0 }
        return store.tasks.filter {
            !$0.isCompleted && $0.isDateAssigned && interval.contains($0.plannedDate)
        }.count
    }

    private var days: [CalendarMonthDay] {
        makeDays(for: monthStart)
    }

    private var weekdayTitles: [String] {
        let symbols = DateFormatter().shortStandaloneWeekdaySymbols ?? ["日", "一", "二", "三", "四", "五", "六"]
        let firstIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "日历", subtitle: monthTitle, count: monthTaskCount) {
                CalendarNavigationControls(
                    onPrevious: { moveMonth(by: -1) },
                    onToday: { store.selectedDate = calendar.startOfCurrentDay() },
                    onNext: { moveMonth(by: 1) }
                )
            }

            CalendarUnscheduledTray()

            weekdayHeader

            GeometryReader { proxy in
                let cellHeight = max((proxy.size.height - 6) / 6, 96)
                let visibleLimit = visibleTaskLimit(for: cellHeight)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(days) { day in
                            CalendarDayCell(day: day, visibleTaskLimit: visibleLimit)
                                .frame(height: cellHeight)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GLBTheme.radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: GLBTheme.radius)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    }
                }
            }
        }
        .padding(GLBTheme.pagePadding)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdayTitles, id: \.self) { title in
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
    }

    private func moveMonth(by value: Int) {
        let newMonth = calendar.date(byAdding: .month, value: value, to: monthStart) ?? monthStart
        store.selectedDate = newMonth
    }

    private func makeDays(for monthStart: Date) -> [CalendarMonthDay] {
        let startWeekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (startWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart

        return (0..<42).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: gridStart) ?? gridStart
            return CalendarMonthDay(
                date: calendar.startOfDay(for: date),
                isCurrentMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                isToday: calendar.isDateInToday(date),
                isSelected: calendar.isDate(date, inSameDayAs: store.selectedDate)
            )
        }
    }

    private func visibleTaskLimit(for cellHeight: CGFloat) -> Int {
        if cellHeight >= 152 { return 5 }
        if cellHeight >= 124 { return 4 }
        return 3
    }
}

private struct CalendarNavigationControls: View {
    var onPrevious: () -> Void
    var onToday: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
            }
            .help("上个月")

            Button("今天", action: onToday)
                .help("回到今天")

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
            }
            .help("下个月")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct CalendarMonthDay: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var isCurrentMonth: Bool
    var isToday: Bool
    var isSelected: Bool
}

private struct CalendarUnscheduledTray: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store

    private var tasks: [TaskItem] {
        store.dateUnassignedTasks()
    }

    private var rowCount: Int {
        tasks.count > 5 ? 2 : 1
    }

    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(32), spacing: 6), count: rowCount)
    }

    private var contentHeight: CGFloat {
        CGFloat(rowCount * 32 + max(rowCount - 1, 0) * 6)
    }

    var body: some View {
        PanelSurface {
            HStack(spacing: 12) {
                IconBadge(systemName: "tray", color: .accentColor)

                Text("待分配")
                    .font(.headline)

                Text("\(tasks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: contentHeight)

                ScrollView(.horizontal) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        if tasks.isEmpty {
                            Text("无")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(height: 32)
                        } else {
                            ForEach(tasks) { task in
                                CalendarUnscheduledChip(task: task)
                                    .draggable(task.id.uuidString)
                            }
                        }
                    }
                    .frame(height: contentHeight)
                }
                .frame(height: contentHeight)
                .scrollIndicators(.hidden)
            }
        }
        .dropDestination(for: String.self) { ids, _ in
            for idString in ids {
                guard let id = UUID(uuidString: idString) else { continue }
                store.unschedule(id: id)
                appState.selectTask(id: id)
            }
            return true
        }
    }
}

private struct CalendarUnscheduledChip: View {
    var task: TaskItem

    private var color: Color {
        task.quadrant?.tintColor ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(task.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: 170, alignment: .leading)
        }
        .foregroundStyle(task.quadrant == .urgentImportant ? .red : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: GLBTheme.radius)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct CalendarDayCell: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store

    var day: CalendarMonthDay
    var visibleTaskLimit: Int

    private let calendar = Calendar.current

    private var tasks: [TaskItem] {
        store.calendarTasks(on: day.date)
    }

    private var overflowCount: Int {
        max(tasks.count - visibleTaskLimit, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                dayNumber

                Spacer()

                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(tasks.prefix(visibleTaskLimit)) { task in
                    CalendarTaskPill(task: task, day: day.date)
                        .draggable(task.id.uuidString)
                }

                if overflowCount > 0 {
                    Text("+\(overflowCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(cellBackground)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedDate = day.date
        }
        .dropDestination(for: String.self) { ids, _ in
            schedule(ids)
        }
    }

    private var dayNumber: some View {
        Text("\(calendar.component(.day, from: day.date))")
            .font(.caption.weight(.semibold))
            .foregroundStyle(dayNumberColor)
            .frame(width: 24, height: 24)
            .background(day.isSelected ? Color.accentColor : Color.clear, in: Circle())
    }

    private var dayNumberColor: Color {
        if day.isSelected {
            return .white
        }
        if day.isToday {
            return .red
        }
        return day.isCurrentMonth ? .primary : .secondary
    }

    private var cellBackground: Color {
        if day.isSelected {
            return Color.accentColor.opacity(0.08)
        }
        if day.isToday {
            return Color.red.opacity(0.035)
        }
        return day.isCurrentMonth ? Color.primary.opacity(0.018) : Color.primary.opacity(0.008)
    }

    private func schedule(_ ids: [String]) -> Bool {
        var handled = false

        for idString in ids {
            guard let id = UUID(uuidString: idString),
                  let task = store.tasks.first(where: { $0.id == id }) else { continue }
            handled = true
            if !task.isDateAssigned || !calendar.isDate(task.plannedDate, inSameDayAs: day.date) {
                store.schedule(id: id, to: day.date)
            }
            appState.selectTask(id: id)
        }

        store.selectedDate = day.date
        return handled
    }
}

private struct CalendarTaskPill: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store

    var task: TaskItem
    var day: Date

    private var color: Color {
        task.quadrant?.tintColor ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(task.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(textColor)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pillBackground, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedDate = day
            appState.selectTask(id: task.id)
        }
        .onTapGesture(count: 2) {
            appState.requestEditTask(id: task.id)
        }
        .contextMenu {
            Button(task.isCompleted ? "取消完成" : "完成") {
                store.toggleCompletion(task)
            }

            Button("编辑内容") {
                appState.requestEditTask(id: task.id)
            }

            Divider()

            Button("删除", role: .destructive) {
                delete()
            }
        }
    }

    private var textColor: Color {
        task.quadrant == .urgentImportant ? .red : .primary
    }

    private var pillBackground: Color {
        return color.opacity(0.10)
    }

    private func delete() {
        if appState.selectedTaskID == task.id {
            appState.selectTask(id: nil)
        }
        store.delete(task)
    }
}
