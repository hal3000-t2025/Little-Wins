import SwiftUI

struct BackupsView: View {
    @Environment(TaskStore.self) private var store
    @State private var snapshots: [BackupSnapshot] = []
    @State private var message: String?
    @State private var restoreCandidate: BackupSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("备份")
                        .font(.largeTitle.weight(.semibold))
                    Text("自动保留最近 30 份")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    refresh()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if snapshots.isEmpty {
                EmptyStateView(title: "还没有备份", symbolName: "externaldrive")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(snapshots) { snapshot in
                    BackupRow(snapshot: snapshot) {
                        restoreCandidate = snapshot
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .onAppear(perform: refresh)
        .confirmationDialog(
            "恢复备份会替换当前数据，当前数据会先保存为恢复点。",
            isPresented: Binding(
                get: { restoreCandidate != nil },
                set: { if !$0 { restoreCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("恢复备份", role: .destructive) {
                restoreSelectedBackup()
            }
            Button("取消", role: .cancel) {
                restoreCandidate = nil
            }
        }
    }

    private func refresh() {
        do {
            snapshots = try store.backupSnapshots()
            message = snapshots.isEmpty ? nil : "找到 \(snapshots.count) 份备份"
        } catch {
            message = "读取备份失败：\(error.localizedDescription)"
        }
    }

    private func restoreSelectedBackup() {
        guard let restoreCandidate else { return }
        do {
            try store.restoreBackup(restoreCandidate)
            message = "已恢复：\(restoreCandidate.title)"
            self.restoreCandidate = nil
            refresh()
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }
}

private struct BackupRow: View {
    var snapshot: BackupSnapshot
    var onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.checkmark")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title)
                    .font(.headline)
                Text("\(snapshot.createdAt.glbDayTitle) · \(snapshot.subtitle)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("恢复") {
                onRestore()
            }
        }
        .padding(.vertical, 6)
    }
}
