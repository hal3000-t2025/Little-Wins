import AppKit
import EventKit
import Foundation

enum CalendarImportAction {
    case created
    case updated
    case removed
    case skipped
}

struct CalendarImportSummary {
    var action: CalendarImportAction
    var date: Date
    var taskCount: Int
    var calendarTitle: String
    var eventTitle: String
}

enum CalendarSyncError: LocalizedError {
    case accessDenied
    case accessRestricted
    case fullAccessRequired
    case noCalendarSource
    case noWritableCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "系统日历权限未开启。请到“系统设置 > 隐私与安全性 > 日历”里允许功劳簿访问。"
        case .accessRestricted:
            "系统限制了日历访问，功劳簿暂时不能导入日程。"
        case .fullAccessRequired:
            "当前只有写入权限，无法更新已有日程。请给功劳簿完整日历访问权限，避免重复导入。"
        case .noCalendarSource:
            "没有找到可以创建日历的账户。请先在系统日历里确认有可写账户。"
        case .noWritableCalendar:
            "没有找到可写的系统日历。请检查系统日历账户是否允许新增事件。"
        }
    }
}

@MainActor
final class CalendarSyncService {
    private let eventStore = EKEventStore()
    private let dayCalendar = Calendar.current
    private let calendarTitle = "功劳簿"
    private let markerPrefix = "GongLaoBu-Day:"

    func importTodayUrgentImportant(tasks: [TaskItem], referenceDate: Date = .now) async throws -> CalendarImportSummary {
        let day = dayCalendar.startOfDay(for: referenceDate)
        let eventTitle = "功劳簿：\(machineDayString(day)) 紧急重要"
        let marker = marker(for: day)
        let dayTasks = tasks
            .filter { task in
                dayCalendar.isDate(task.plannedDate, inSameDayAs: day) && task.quadrant == .urgentImportant
            }
            .sorted(by: taskSort)

        guard !dayTasks.isEmpty else {
            guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
                  let targetCalendar = existingCalendar(),
                  let existingEvent = existingDayEvent(on: day, in: targetCalendar, marker: marker, eventTitle: eventTitle) else {
                return CalendarImportSummary(
                    action: .skipped,
                    date: day,
                    taskCount: 0,
                    calendarTitle: calendarTitle,
                    eventTitle: eventTitle
                )
            }

            try eventStore.remove(existingEvent, span: .thisEvent)
            return CalendarImportSummary(
                action: .removed,
                date: day,
                taskCount: 0,
                calendarTitle: calendarTitle,
                eventTitle: eventTitle
            )
        }

        try await ensureFullAccess()

        let targetCalendar = try ensureCalendar()
        let existingEvent = existingDayEvent(on: day, in: targetCalendar, marker: marker, eventTitle: eventTitle)
        let event = existingEvent ?? EKEvent(eventStore: eventStore)
        event.calendar = targetCalendar
        event.title = eventTitle
        event.notes = notes(for: dayTasks, on: day, marker: marker)
        event.startDate = day
        event.endDate = dayCalendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        event.isAllDay = true
        event.availability = .free

        try eventStore.save(event, span: .thisEvent)

        return CalendarImportSummary(
            action: existingEvent == nil ? .created : .updated,
            date: day,
            taskCount: dayTasks.count,
            calendarTitle: calendarTitle,
            eventTitle: eventTitle
        )
    }

    private func ensureFullAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return
        case .notDetermined, .writeOnly:
            let granted = try await requestFullAccess()
            guard granted else { throw CalendarSyncError.fullAccessRequired }
        case .denied:
            throw CalendarSyncError.accessDenied
        case .restricted:
            throw CalendarSyncError.accessRestricted
        @unknown default:
            throw CalendarSyncError.accessDenied
        }
    }

    private func requestFullAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func ensureCalendar() throws -> EKCalendar {
        if let existing = existingCalendar() {
            return existing
        }

        var lastError: Error?
        for source in calendarSources() {
            let calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar.title = calendarTitle
            calendar.source = source
            calendar.color = .systemRed

            do {
                try eventStore.saveCalendar(calendar, commit: true)
                return calendar
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        throw CalendarSyncError.noCalendarSource
    }

    private func existingCalendar() -> EKCalendar? {
        eventStore
            .calendars(for: .event)
            .first(where: { $0.title == calendarTitle && $0.allowsContentModifications })
    }

    private func calendarSources() -> [EKSource] {
        var sources: [EKSource] = []
        var seen = Set<String>()

        append(eventStore.defaultCalendarForNewEvents?.source, to: &sources, seen: &seen)
        eventStore.sources
            .filter { $0.sourceType == .local }
            .forEach { append($0, to: &sources, seen: &seen) }
        eventStore.sources
            .filter { $0.sourceType == .calDAV || $0.sourceType == .exchange }
            .forEach { append($0, to: &sources, seen: &seen) }
        eventStore.sources
            .filter { $0.sourceType != .subscribed && $0.sourceType != .birthdays }
            .forEach { append($0, to: &sources, seen: &seen) }

        return sources
    }

    private func append(_ source: EKSource?, to sources: inout [EKSource], seen: inout Set<String>) {
        guard let source, !seen.contains(source.sourceIdentifier) else { return }
        sources.append(source)
        seen.insert(source.sourceIdentifier)
    }

    private func existingDayEvent(on day: Date, in calendar: EKCalendar, marker: String, eventTitle: String) -> EKEvent? {
        let end = dayCalendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let predicate = eventStore.predicateForEvents(withStart: day, end: end, calendars: [calendar])

        return eventStore.events(matching: predicate).first { event in
            if event.notes?.contains(marker) == true {
                return true
            }
            return event.title == eventTitle && dayCalendar.isDate(event.startDate, inSameDayAs: day)
        }
    }

    private func notes(for tasks: [TaskItem], on day: Date, marker: String) -> String {
        let taskLines = tasks.enumerated().map { index, task in
            let status = task.isCompleted ? "[x]" : "[ ]"
            return "\(index + 1). \(status) \(task.title)"
        }

        return ([
            marker,
            "来源：功劳簿",
            "日期：\(day.glbDayTitle)",
            "象限：紧急重要",
            "更新：\(Date.now.formatted(date: .omitted, time: .shortened))",
            "",
            "任务："
        ] + taskLines).joined(separator: "\n")
    }

    private func marker(for day: Date) -> String {
        "\(markerPrefix)\(machineDayString(day))"
    }

    private func machineDayString(_ day: Date) -> String {
        let components = dayCalendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func taskSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.createdAt < rhs.createdAt
    }
}
