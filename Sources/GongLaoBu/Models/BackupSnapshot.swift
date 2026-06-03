import Foundation

struct BackupSnapshot: Identifiable, Hashable {
    var id: URL { url }
    var url: URL
    var createdAt: Date
    var taskCount: Int
    var byteCount: Int

    var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    var subtitle: String {
        "\(taskCount) 件任务 · \(formattedByteCount)"
    }

    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}
