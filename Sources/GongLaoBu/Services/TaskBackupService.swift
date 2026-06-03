import Foundation

struct TaskBackupService {
    private let calendar: Calendar
    private let fileManager: FileManager
    private let maxBackups: Int

    init(
        calendar: Calendar = .current,
        fileManager: FileManager = .default,
        maxBackups: Int = 30
    ) {
        self.calendar = calendar
        self.fileManager = fileManager
        self.maxBackups = maxBackups
    }

    func createDailyBackupIfNeeded(sourceURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }

        let backupDirectory = backupDirectory(for: sourceURL)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let backupURL = backupDirectory.appendingPathComponent("tasks-\(dayStamp(for: .now)).json")
        guard !fileManager.fileExists(atPath: backupURL.path) else {
            try pruneBackups(in: backupDirectory)
            return
        }

        try fileManager.copyItem(at: sourceURL, to: backupURL)
        try pruneBackups(in: backupDirectory)
    }

    func createRestorePoint(sourceURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }

        let backupDirectory = backupDirectory(for: sourceURL)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let backupURL = backupDirectory.appendingPathComponent("restore-point-\(timestamp(for: .now)).json")
        try fileManager.copyItem(at: sourceURL, to: backupURL)
        try pruneBackups(in: backupDirectory)
    }

    func listBackups(sourceURL: URL) throws -> [BackupSnapshot] {
        let directory = backupDirectory(for: sourceURL)
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        return try fileManager
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                let values = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
                let data = try Data(contentsOf: url)
                let tasks = (try? JSONDecoder().decode([TaskItem].self, from: data)) ?? []
                return BackupSnapshot(
                    url: url,
                    createdAt: values.contentModificationDate ?? values.creationDate ?? .distantPast,
                    taskCount: tasks.count,
                    byteCount: values.fileSize ?? data.count
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func restore(snapshot: BackupSnapshot, to sourceURL: URL) throws {
        guard fileManager.fileExists(atPath: snapshot.url.path) else { return }

        try createRestorePoint(sourceURL: sourceURL)
        try fileManager.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: sourceURL.path) {
            try fileManager.removeItem(at: sourceURL)
        }

        try fileManager.copyItem(at: snapshot.url, to: sourceURL)
    }

    private func backupDirectory(for sourceURL: URL) -> URL {
        sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
    }

    private func pruneBackups(in directory: URL) throws {
        let backups = try fileManager
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }

        for backup in backups.dropFirst(maxBackups) {
            try fileManager.removeItem(at: backup)
        }
    }

    private func dayStamp(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func timestamp(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d-%02d-%02d-%02d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}
