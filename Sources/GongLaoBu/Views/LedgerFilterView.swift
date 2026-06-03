import SwiftUI

struct LedgerFilterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("功劳簿筛选")
                    .font(.largeTitle.weight(.semibold))
                Text("筛选会影响功劳簿页面显示。")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("搜索")
                    .font(.headline)
                TextField("搜索功劳簿", text: $appState.ledgerSearchText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("时间")
                    .font(.headline)
                Picker("时间", selection: $appState.ledgerDateFilter) {
                    ForEach(LedgerDateFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("象限")
                    .font(.headline)
                Picker("象限", selection: $appState.ledgerQuadrantFilter) {
                    ForEach(LedgerQuadrantFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220, alignment: .leading)
            }

            HStack {
                Button("清除筛选") {
                    appState.clearLedgerFilters()
                }

                Spacer()
            }
        }
        .padding(24)
    }
}
