import AppKit
import Foundation
import UniformTypeIdentifiers

enum TaskExportFormat {
    case json
    case csv

    var title: String {
        switch self {
        case .json:
            "JSON"
        case .csv:
            "CSV"
        }
    }

    var fileExtension: String {
        switch self {
        case .json:
            "json"
        case .csv:
            "csv"
        }
    }

    var contentType: UTType {
        switch self {
        case .json:
            .json
        case .csv:
            .commaSeparatedText
        }
    }
}

enum TaskExportService {
    @MainActor
    static func export(tasks: [TaskItem], format: TaskExportFormat) throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "gonglaobu-\(dayStamp()).\(format.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let data = try exportData(tasks: tasks, format: format)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportData(tasks: [TaskItem], format: TaskExportFormat) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(tasks.sorted(by: taskExportSort))
        case .csv:
            return csvData(tasks: tasks)
        }
    }

    private static func csvData(tasks: [TaskItem]) -> Data {
        let header = [
            "id",
            "title",
            "createdAt",
            "plannedDate",
            "isDateAssigned",
            "completedAt",
            "isCompleted",
            "quadrant",
            "sortOrder",
            "carryOverCount",
            "aiCategory"
        ]

        let rows = tasks.sorted(by: taskExportSort).map { task in
            [
                task.id.uuidString,
                task.title,
                isoDate(task.createdAt),
                isoDate(task.plannedDate),
                task.isDateAssigned ? "true" : "false",
                task.completedAt.map(isoDate) ?? "",
                task.isCompleted ? "true" : "false",
                task.quadrant?.title ?? "",
                "\(task.sortOrder)",
                "\(task.carryOverCount)",
                task.aiCategory ?? ""
            ]
        }

        let csv = ([header] + rows)
            .map { row in row.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")
        return Data(csv.utf8)
    }

    private static func taskExportSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isDateAssigned != rhs.isDateAssigned {
            return !lhs.isDateAssigned
        }
        if lhs.plannedDate != rhs.plannedDate {
            return lhs.plannedDate < rhs.plannedDate
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.createdAt < rhs.createdAt
    }

    private static func escapeCSV(_ value: String) -> String {
        let mustQuote = value.contains(",") || value.contains("\"") || value.contains("\n")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return mustQuote ? "\"\(escaped)\"" : escaped
    }

    private static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func dayStamp() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
