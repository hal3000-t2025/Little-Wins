import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(TaskStore.self) private var store

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView(selection: $appState.selectedPage)
                .navigationSplitViewColumnWidth(min: 170, ideal: 205, max: 240)
        } detail: {
            pageView
                .navigationTitle("")
                .safeAreaPadding(.top, 10)
        }
        .overlay(alignment: .bottom) {
            if let task = store.recentlyDeletedTask {
                DeletedTaskBanner(task: task)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: store.recentlyDeletedTask?.id)
    }

    @ViewBuilder
    private var pageView: some View {
        switch appState.currentPage {
        case .inbox:
            InboxView()
        case .quadrants:
            QuadrantBoardView()
        case .calendar:
            CalendarPageView()
        case .ledger:
            LedgerView()
        case .statistics:
            StatisticsView()
        }
    }
}

private struct DeletedTaskBanner: View {
    @Environment(TaskStore.self) private var store
    var task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)

            Text("已删除：\(task.title)")
                .lineLimit(1)

            Button("撤销") {
                store.undoDelete()
            }
            .keyboardShortcut("z", modifiers: .command)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(radius: 12, y: 4)
        .frame(maxWidth: 520)
    }
}
