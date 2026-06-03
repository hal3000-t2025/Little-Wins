import Foundation
import Observation

@Observable
final class TaskStore {
    var tasks: [TaskItem] = []
    var selectedDate: Date
    var recentlyDeletedTask: TaskItem?
    var carryOverNotice: CarryOverNotice?

    var canUndoDelete: Bool {
        recentlyDeletedTask != nil
    }

    @ObservationIgnored private let calendar = Calendar.current
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let backupService = TaskBackupService()

    init(fileURL: URL = TaskStore.defaultStorageURL()) {
        self.fileURL = fileURL
        self.selectedDate = Calendar.current.startOfDay(for: .now)
        load()
        carryOverOverdueTasks()
    }

    func addTask(title: String, plannedDate: Date = .now) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let day = calendar.startOfDay(for: plannedDate)
        let task = TaskItem(
            title: trimmed,
            plannedDate: day,
            isDateAssigned: false,
            sortOrder: nextSortOrder(quadrant: nil)
        )
        tasks.append(task)
        normalizeSortOrders(quadrant: nil)
        save()
    }

    func inboxTasks(on date: Date = .now) -> [TaskItem] {
        tasks
            .filter { !$0.isCompleted && (!$0.isDateAssigned || $0.quadrant == nil) }
            .sorted(by: planningSort)
    }

    func dateUnassignedTasks() -> [TaskItem] {
        tasks
            .filter { !$0.isCompleted && !$0.isDateAssigned }
            .sorted(by: planningSort)
    }

    func quadrantUnassignedTasks() -> [TaskItem] {
        tasks
            .filter { !$0.isCompleted && $0.quadrant == nil }
            .sorted(by: planningSort)
    }

    func activeTasks(in quadrant: TaskQuadrant) -> [TaskItem] {
        tasks
            .filter { !$0.isCompleted && $0.quadrant == quadrant }
            .sorted(by: taskSort)
    }

    func calendarTasks(on date: Date) -> [TaskItem] {
        tasks
            .filter { !$0.isCompleted && $0.isDateAssigned && calendar.isDate($0.plannedDate, inSameDayAs: date) }
            .sorted { lhs, rhs in
                let leftRank = lhs.quadrant?.sortRank ?? 4
                let rightRank = rhs.quadrant?.sortRank ?? 4
                if leftRank != rightRank { return leftRank < rightRank }
                return taskSort(lhs, rhs)
            }
    }

    func completedGroups() -> [CompletedTaskGroup] {
        let completed = tasks.filter { $0.completedAt != nil }
        let grouped = Dictionary(grouping: completed) { task in
            calendar.startOfDay(for: task.completedAt ?? task.plannedDate)
        }

        return grouped.keys.sorted(by: >).map { day in
            let tasks = (grouped[day] ?? []).sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
            return CompletedTaskGroup(date: day, tasks: tasks)
        }
    }

    func ledgerStats(referenceDate: Date = .now) -> LedgerStats {
        let completedDates = tasks.compactMap(\.completedAt)
        let today = completedDates.filter { calendar.isDate($0, inSameDayAs: referenceDate) }.count
        let week = completedDates.filter { calendar.contains($0, in: calendar.dateInterval(of: .weekOfYear, for: referenceDate)) }.count
        let month = completedDates.filter { calendar.contains($0, in: calendar.dateInterval(of: .month, for: referenceDate)) }.count
        let year = completedDates.filter { calendar.contains($0, in: calendar.dateInterval(of: .year, for: referenceDate)) }.count

        return LedgerStats(
            today: today,
            week: week,
            month: month,
            year: year,
            total: completedDates.count
        )
    }

    func dailyCompletionCounts(days: Int, referenceDate: Date = .now) -> [DailyCompletionCount] {
        let endDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: endDay) ?? endDay

        return (0..<max(days, 1)).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay
            let count = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            return DailyCompletionCount(date: day, count: count)
        }
    }

    func quadrantCompletionCounts(in interval: DateInterval? = nil) -> [QuadrantCompletionCount] {
        let completed = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            guard let interval else { return true }
            return interval.contains(completedAt)
        }

        let grouped = Dictionary(grouping: completed, by: \.quadrant)
        var result = TaskQuadrant.allCases.map { quadrant in
            QuadrantCompletionCount(
                title: quadrant.title,
                count: grouped[quadrant, default: []].count,
                quadrant: quadrant
            )
        }
        result.append(
            QuadrantCompletionCount(
                title: "未分配",
                count: grouped[nil, default: []].count,
                quadrant: nil
            )
        )
        return result
    }

    func delayedTaskSummaries(limit: Int = 8) -> [DelaySummary] {
        tasks
            .filter { $0.carryOverCount > 0 }
            .sorted {
                if $0.carryOverCount != $1.carryOverCount {
                    return $0.carryOverCount > $1.carryOverCount
                }
                return $0.createdAt < $1.createdAt
            }
            .prefix(limit)
            .map { DelaySummary(task: $0, count: $0.carryOverCount) }
    }

    func tasksNeedingAICategory(limit: Int = 120) -> [TaskItem] {
        tasks
            .filter { task in
                task.aiCategory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted
                }
                if $0.plannedDate != $1.plannedDate {
                    return $0.plannedDate > $1.plannedDate
                }
                return $0.createdAt > $1.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func applyAICategories(_ categories: [UUID: String]) {
        var changed = false
        for index in tasks.indices {
            guard let category = categories[tasks[index].id] else { continue }
            tasks[index].aiCategory = category
            changed = true
        }

        if changed {
            save()
        }
    }

    func backupSnapshots() throws -> [BackupSnapshot] {
        try backupService.listBackups(sourceURL: fileURL)
    }

    func restoreBackup(_ snapshot: BackupSnapshot) throws {
        try backupService.restore(snapshot: snapshot, to: fileURL)
        load()
        recentlyDeletedTask = nil
        carryOverNotice = nil
    }

    func assignTask(idString: String, to quadrant: TaskQuadrant?) {
        guard let id = UUID(uuidString: idString) else { return }
        assignTask(id: id, to: quadrant)
    }

    func assignTask(id: UUID, to quadrant: TaskQuadrant?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let previousQuadrant = tasks[index].quadrant
        tasks[index].quadrant = quadrant
        tasks[index].sortOrder = nextSortOrder(quadrant: quadrant)
        normalizeSortOrders(quadrant: previousQuadrant)
        normalizeSortOrders(quadrant: quadrant)
        save()
    }

    func schedule(_ task: TaskItem, to date: Date) {
        schedule(id: task.id, to: date)
    }

    func schedule(id: UUID, to date: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard !tasks[index].isCompleted else { return }
        let newDay = calendar.startOfDay(for: date)

        tasks[index].plannedDate = newDay
        tasks[index].isDateAssigned = true
        save()
    }

    func unschedule(idString: String) {
        guard let id = UUID(uuidString: idString) else { return }
        unschedule(id: id)
    }

    func unschedule(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard !tasks[index].isCompleted else { return }
        tasks[index].isDateAssigned = false
        save()
    }

    func toggleCompletion(_ task: TaskItem) {
        toggleCompletion(id: task.id)
    }

    func toggleCompletion(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completedAt = tasks[index].completedAt == nil ? .now : nil
        save()
    }

    func rename(_ task: TaskItem, to title: String) {
        rename(id: task.id, to: title)
    }

    func rename(id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = trimmed
        save()
    }

    func delete(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let deletedTask = tasks[index]
        recentlyDeletedTask = deletedTask
        tasks.remove(at: index)

        if !deletedTask.isCompleted {
            normalizeSortOrders(quadrant: deletedTask.quadrant)
        }

        save()
    }

    func undoDelete() {
        guard let task = recentlyDeletedTask else { return }
        guard !tasks.contains(where: { $0.id == task.id }) else {
            recentlyDeletedTask = nil
            return
        }

        tasks.append(task)

        if !task.isCompleted {
            normalizeSortOrders(quadrant: task.quadrant)
        }

        recentlyDeletedTask = nil
        save()
    }

    func move(_ task: TaskItem, by offset: Int) {
        guard let currentIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let quadrant = tasks[currentIndex].quadrant
        let group = tasks
            .filter { !$0.isCompleted && $0.quadrant == quadrant }
            .sorted(by: taskSort)

        guard let currentGroupIndex = group.firstIndex(where: { $0.id == task.id }) else { return }
        let targetGroupIndex = currentGroupIndex + offset
        guard group.indices.contains(targetGroupIndex) else { return }

        let targetID = group[targetGroupIndex].id
        guard let targetIndex = tasks.firstIndex(where: { $0.id == targetID }) else { return }

        let currentOrder = tasks[currentIndex].sortOrder
        tasks[currentIndex].sortOrder = tasks[targetIndex].sortOrder
        tasks[targetIndex].sortOrder = currentOrder
        normalizeSortOrders(quadrant: quadrant)
        save()
    }

    func placeTask(idString: String, before targetTask: TaskItem) {
        guard let id = UUID(uuidString: idString) else { return }
        placeTask(id: id, before: targetTask.id)
    }

    func placeTask(id: UUID, before targetID: UUID) {
        guard id != targetID else { return }
        guard let movingIndex = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard let targetIndex = tasks.firstIndex(where: { $0.id == targetID }) else { return }
        guard !tasks[movingIndex].isCompleted, !tasks[targetIndex].isCompleted else { return }

        let previousQuadrant = tasks[movingIndex].quadrant
        let targetQuadrant = tasks[targetIndex].quadrant

        tasks[movingIndex].quadrant = targetQuadrant

        var orderedIDs = tasks
            .filter { !$0.isCompleted && $0.quadrant == targetQuadrant && $0.id != id }
            .sorted(by: taskSort)
            .map(\.id)

        let insertIndex = orderedIDs.firstIndex(of: targetID) ?? orderedIDs.count
        orderedIDs.insert(id, at: insertIndex)

        for (order, taskID) in orderedIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { continue }
            tasks[index].sortOrder = order
        }

        if previousQuadrant != targetQuadrant {
            normalizeSortOrders(quadrant: previousQuadrant)
        }
        save()
    }

    func dismissCarryOverNotice() {
        carryOverNotice = nil
    }

    private func carryOverOverdueTasks() {
        let today = calendar.startOfCurrentDay()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var nextInboxOrder = nextSortOrder(quadrant: nil)
        var carriedCount = 0
        var includesOlderTasks = false
        var changed = false

        for index in tasks.indices {
            guard !tasks[index].isCompleted, tasks[index].isDateAssigned, tasks[index].plannedDate < today else { continue }
            if tasks[index].plannedDate < yesterday {
                includesOlderTasks = true
            }
            let days = max(1, calendar.dateComponents([.day], from: tasks[index].plannedDate, to: today).day ?? 1)
            tasks[index].plannedDate = today
            tasks[index].isDateAssigned = false
            tasks[index].quadrant = nil
            tasks[index].sortOrder = nextInboxOrder
            tasks[index].carryOverCount += days
            nextInboxOrder += 1
            carriedCount += 1
            changed = true
        }

        if changed {
            normalizeSortOrders(quadrant: nil)
            carryOverNotice = CarryOverNotice(
                count: carriedCount,
                includesOlderTasks: includesOlderTasks
            )
            save()
        }
    }

    private func taskSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.createdAt < rhs.createdAt
    }

    private func planningSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isDateAssigned != rhs.isDateAssigned {
            return !lhs.isDateAssigned
        }

        let leftRank = lhs.quadrant?.sortRank ?? 4
        let rightRank = rhs.quadrant?.sortRank ?? 4
        if leftRank != rightRank {
            return leftRank < rightRank
        }

        if lhs.plannedDate != rhs.plannedDate {
            return lhs.plannedDate < rhs.plannedDate
        }

        return taskSort(lhs, rhs)
    }

    private func nextSortOrder(quadrant: TaskQuadrant?) -> Int {
        let currentMax = tasks
            .filter { !$0.isCompleted && $0.quadrant == quadrant }
            .map(\.sortOrder)
            .max()
        return (currentMax ?? -1) + 1
    }

    private func normalizeSortOrders(quadrant: TaskQuadrant?) {
        let sortedIDs = tasks
            .filter { !$0.isCompleted && $0.quadrant == quadrant }
            .sorted(by: taskSort)
            .map(\.id)

        for (order, id) in sortedIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == id }) else { continue }
            tasks[index].sortOrder = order
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            tasks = try decoder.decode([TaskItem].self, from: data)
        } catch {
            print("Failed to load tasks: \(error)")
            tasks = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            do {
                try backupService.createDailyBackupIfNeeded(sourceURL: fileURL)
            } catch {
                print("Failed to create daily backup: \(error)")
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tasks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save tasks: \(error)")
        }
    }

    private static func defaultStorageURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL
            .appendingPathComponent("GongLaoBu", isDirectory: true)
            .appendingPathComponent("tasks.json")
    }
}
