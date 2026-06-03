import SwiftUI

struct InboxView: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store
    @FocusState private var isInputFocused: Bool
    @State private var draftTitle = ""

    private var tasks: [TaskItem] {
        store.inboxTasks()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Inbox", subtitle: Date.now.glbDayTitle, count: tasks.count)

            if let notice = store.carryOverNotice {
                CarryOverNoticeView(notice: notice)
            }

            PanelSurface {
                HStack(spacing: 10) {
                    TextField("写下今天要做的事", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.medium))
                        .focused($isInputFocused)
                        .onSubmit(addTask)

                    Button(action: addTask) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("添加")
                }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if tasks.isEmpty {
                        EmptyStateView(title: "Inbox 为空", symbolName: "tray")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        ForEach(tasks) { task in
                            TaskRowView(
                                task: task,
                                isSelected: appState.selectedTaskID == task.id,
                                onSelect: { appState.selectTask(id: task.id) },
                                onToggle: { store.toggleCompletion(task) },
                                onRename: { store.rename(task, to: $0) },
                                onDelete: { delete(task) }
                            )
                            .draggable(task.id.uuidString)
                            .contextMenu {
                                Button("编辑内容") {
                                    appState.requestEditTask(id: task.id)
                                }
                                ForEach(TaskQuadrant.allCases) { quadrant in
                                    Button(quadrant.title) {
                                        store.assignTask(id: task.id, to: quadrant)
                                    }
                                }
                            }
                            .dropDestination(for: String.self) { ids, _ in
                                ids.forEach { store.placeTask(idString: $0, before: task) }
                                return true
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .dropDestination(for: String.self) { ids, _ in
                ids.forEach { store.assignTask(idString: $0, to: nil) }
                return true
            }
        }
        .padding(GLBTheme.pagePadding)
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: appState.newTaskFocusRequest) { _, _ in
            isInputFocused = true
        }
    }

    private func addTask() {
        store.addTask(title: draftTitle)
        draftTitle = ""
        isInputFocused = true
    }

    private func delete(_ task: TaskItem) {
        if appState.selectedTaskID == task.id {
            appState.selectTask(id: nil)
        }
        store.delete(task)
    }
}

private struct CarryOverNoticeView: View {
    @Environment(TaskStore.self) private var store
    var notice: CarryOverNotice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.forward.circle.fill")
                .foregroundStyle(.orange)

            Text(notice.title)
                .font(.callout.weight(.medium))

            Spacer()

            Button {
                store.dismissCarryOverNotice()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("关闭")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: GLBTheme.radius)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        }
    }
}

struct EmptyStateView: View {
    var title: String
    var symbolName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
