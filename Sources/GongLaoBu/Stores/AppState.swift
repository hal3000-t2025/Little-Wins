import Foundation
import Observation

@Observable
final class AppState {
    var selectedPage: AppPage? = .inbox
    var selectedTaskID: UUID?
    var editTaskRequestID: UUID?
    var newTaskFocusRequest = 0
    var ledgerSearchText = ""
    var ledgerDateFilter: LedgerDateFilter = .all
    var ledgerQuadrantFilter: LedgerQuadrantFilter = .all

    var currentPage: AppPage {
        selectedPage ?? .inbox
    }

    var hasLedgerFilter: Bool {
        !ledgerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            ledgerDateFilter != .all ||
            ledgerQuadrantFilter != .all
    }

    func selectPage(_ page: AppPage) {
        selectedPage = page
    }

    func requestNewTask() {
        selectedPage = .inbox
        newTaskFocusRequest += 1
    }

    func selectTask(id: UUID?) {
        selectedTaskID = id
    }

    func requestEditTask(id: UUID) {
        selectedTaskID = id
        editTaskRequestID = id
    }

    func clearEditTaskRequest() {
        editTaskRequestID = nil
    }

    func clearLedgerFilters() {
        ledgerSearchText = ""
        ledgerDateFilter = .all
        ledgerQuadrantFilter = .all
    }
}
