import SwiftUI

struct SidebarView: View {
    @Environment(TaskStore.self) private var store
    @Binding var selection: AppPage?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(AppPage.allCases) { page in
                    Label(page.title, systemImage: page.symbolName)
                        .tag(page)
                }
            }

            Section("概览") {
                SidebarMetricRow(title: "Inbox", value: store.inboxTasks().count, symbolName: "tray")
                SidebarMetricRow(title: "今日完成", value: store.ledgerStats().today, symbolName: "checkmark.circle")
            }
        }
        .listStyle(.sidebar)
        .safeAreaPadding(.top, 18)
    }
}

private struct SidebarMetricRow: View {
    var title: String
    var value: Int
    var symbolName: String

    var body: some View {
        HStack {
            Label(title, systemImage: symbolName)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
