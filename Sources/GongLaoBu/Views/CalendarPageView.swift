import SwiftUI

struct CalendarPageView: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { store.selectedDate },
            set: { store.selectedDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var tasks: [TaskItem] {
        store.calendarTasks(on: store.selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "日历", subtitle: store.selectedDate.glbDayTitle, count: tasks.count) {
                DatePicker("", selection: selectedDateBinding, displayedComponents: .date)
                    .labelsHidden()
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if tasks.isEmpty {
                        EmptyStateView(title: "这天没有任务", symbolName: "calendar")
                            .frame(maxWidth: .infinity, minHeight: 260)
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
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(GLBTheme.pagePadding)
    }

    private func delete(_ task: TaskItem) {
        if appState.selectedTaskID == task.id {
            appState.selectTask(id: nil)
        }
        store.delete(task)
    }
}
