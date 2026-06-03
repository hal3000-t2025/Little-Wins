import SwiftUI

struct QuadrantBoardView: View {
    @Environment(TaskStore.self) private var store

    private let singleColumnWidthThreshold: CGFloat = 720

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "权重", subtitle: Date.now.glbDayTitle)

                    UnassignedTray()

                    LazyVGrid(columns: columns(for: proxy.size.width), alignment: .leading, spacing: 14) {
                        ForEach(TaskQuadrant.allCases) { quadrant in
                            QuadrantPanel(quadrant: quadrant, height: panelHeight(for: proxy.size))
                        }
                    }
                }
                .padding(GLBTheme.pagePadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        if width < singleColumnWidthThreshold {
            return [GridItem(.flexible(), spacing: 14)]
        }

        return [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private func panelHeight(for size: CGSize) -> CGFloat {
        if size.width < singleColumnWidthThreshold {
            return min(max(size.height * 0.58, 300), 520)
        }

        let reservedHeight = GLBTheme.pagePadding * 2 + 68 + 128 + 14
        let availableGridHeight = max(size.height - reservedHeight, 0)
        return min(max((availableGridHeight - 14) / 2, 260), 420)
    }
}

private struct UnassignedTray: View {
    @Environment(TaskStore.self) private var store

    private var tasks: [TaskItem] {
        store.inboxTasks()
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(systemName: "tray", color: .accentColor)
                    Text("待分配")
                        .font(.headline)
                    Spacer()
                    Text("\(tasks.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        if tasks.isEmpty {
                            Text("无")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(height: 38)
                        } else {
                            ForEach(tasks) { task in
                                TaskChipView(task: task)
                                    .draggable(task.id.uuidString)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
        .dropDestination(for: String.self) { ids, _ in
            ids.forEach { store.assignTask(idString: $0, to: nil) }
            return true
        }
    }
}

private struct QuadrantPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store
    var quadrant: TaskQuadrant
    var height: CGFloat

    private var tasks: [TaskItem] {
        store.activeTasks(in: quadrant)
    }

    var body: some View {
        PanelSurface(tint: quadrant.tintColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(systemName: quadrant.symbolName, color: quadrant.tintColor)
                    Text(quadrant.title)
                        .font(.headline)
                        .foregroundStyle(quadrant.tintColor)

                    Spacer()

                    Text("\(tasks.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Divider()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if tasks.isEmpty {
                            EmptyStateView(title: "空", symbolName: quadrant.symbolName)
                                .frame(maxWidth: .infinity, minHeight: 150)
                        } else {
                            ForEach(tasks) { task in
                                TaskRowView(
                                    task: task,
                                    isSelected: appState.selectedTaskID == task.id,
                                    showsQuadrantBadge: false,
                                    onSelect: { appState.selectTask(id: task.id) },
                                    onToggle: { store.toggleCompletion(task) },
                                    onRename: { store.rename(task, to: $0) },
                                    onDelete: { delete(task) }
                                )
                                .draggable(task.id.uuidString)
                                .dropDestination(for: String.self) { ids, _ in
                                    ids.forEach { store.placeTask(idString: $0, before: task) }
                                    return true
                                }
                                .contextMenu {
                                    Button("编辑内容") {
                                        appState.requestEditTask(id: task.id)
                                    }
                                    Divider()
                                    Button("回到 Inbox") {
                                        store.assignTask(id: task.id, to: nil)
                                    }
                                    Divider()
                                    ForEach(TaskQuadrant.allCases) { target in
                                        Button(target.title) {
                                            store.assignTask(id: task.id, to: target)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.automatic)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(quadrant.panelFill, in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .frame(height: height, alignment: .top)
        .dropDestination(for: String.self) { ids, _ in
            ids.forEach { store.assignTask(idString: $0, to: quadrant) }
            return true
        }
    }

    private func delete(_ task: TaskItem) {
        if appState.selectedTaskID == task.id {
            appState.selectTask(id: nil)
        }
        store.delete(task)
    }
}
