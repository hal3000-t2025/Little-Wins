import AppKit
import SwiftUI

@main
struct GongLaoBuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var appState = AppState()
    @State private var store = TaskStore()
    @State private var aiConfig = AIConfigStore()
    @State private var calendarSync = CalendarSyncService()

    var body: some Scene {
        WindowGroup("功劳簿") {
            ContentView()
                .environment(appState)
                .environment(store)
                .environment(aiConfig)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    await aiConfig.validateSavedKeyIfNeeded()
                }
        }

        Window("备份", id: "backups") {
            BackupsView()
                .environment(store)
                .frame(minWidth: 720, minHeight: 520)
        }

        Window("DeepSeek 设置", id: "aiSettings") {
            AISettingsView()
                .environment(aiConfig)
                .frame(minWidth: 520, minHeight: 420)
        }

        Window("功劳簿筛选", id: "ledgerFilters") {
            LedgerFilterView()
                .environment(appState)
                .frame(minWidth: 440, minHeight: 360)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于功劳簿") {
                    showAboutPanel()
                }
            }

            CommandGroup(after: .newItem) {
                Button("新建任务") {
                    appState.requestNewTask()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("页面") {
                Button("Inbox") {
                    appState.selectPage(.inbox)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("权重") {
                    appState.selectPage(.quadrants)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("日历") {
                    appState.selectPage(.calendar)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("功劳簿") {
                    appState.selectPage(.ledger)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("统计") {
                    appState.selectPage(.statistics)
                }
                .keyboardShortcut("5", modifiers: .command)
            }

            CommandMenu("任务") {
                Button("完成选中任务") {
                    guard let id = appState.selectedTaskID else { return }
                    store.toggleCompletion(id: id)
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(appState.selectedTaskID == nil)

                Button("撤销删除") {
                    store.undoDelete()
                }
                .disabled(!store.canUndoDelete)
            }

            CommandMenu("功劳簿") {
                Button("导出 JSON") {
                    exportLedger(.json)
                }

                Button("导出 CSV") {
                    exportLedger(.csv)
                }

                Divider()

                Button("筛选功劳簿") {
                    openWindow(id: "ledgerFilters")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("清除功劳簿筛选") {
                    appState.clearLedgerFilters()
                }
                .disabled(!appState.hasLedgerFilter)
            }

            CommandMenu("系统日历") {
                Button("导入今日紧急重要") {
                    Task {
                        await importTodayUrgentImportantToSystemCalendar()
                    }
                }
            }

            CommandMenu("AI") {
                Button("DeepSeek 设置") {
                    openWindow(id: "aiSettings")
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])

                Button("测试 DeepSeek 连接") {
                    Task {
                        await aiConfig.saveAndValidate()
                    }
                }
                .disabled(aiConfig.isChecking || aiConfig.isClassifying)

                Divider()

                Button("自动分类事项") {
                    Task {
                        await classifyTasks()
                    }
                }
                .disabled(!aiConfig.canUseAI)
            }

            CommandGroup(after: .saveItem) {
                Button("备份管理") {
                    openWindow(id: "backups")
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }
    }

    private func exportLedger(_ format: TaskExportFormat) {
        do {
            _ = try TaskExportService.export(tasks: store.tasks, format: format)
        } catch {
            print("Failed to export ledger: \(error)")
        }
    }

    private func showAboutPanel() {
        let credits = NSAttributedString(
            string: "作者：hal3000",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "功劳簿",
                .applicationVersion: "0.1.0",
                .version: "Build 1",
                .credits: credits
            ]
        )
    }

    @MainActor
    private func importTodayUrgentImportantToSystemCalendar() async {
        do {
            let summary = try await calendarSync.importTodayUrgentImportant(tasks: store.tasks)
            presentCalendarImportResult(summary)
        } catch {
            presentCalendarImportFailure(error)
        }
    }

    @MainActor
    private func presentCalendarImportResult(_ summary: CalendarImportSummary) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")

        switch summary.action {
        case .created:
            alert.messageText = "已导入系统日历"
            alert.informativeText = "已在“\(summary.calendarTitle)”日历中创建“\(summary.eventTitle)”，共 \(summary.taskCount) 件。"
        case .updated:
            alert.messageText = "已更新系统日历"
            alert.informativeText = "已更新“\(summary.eventTitle)”，现在包含 \(summary.taskCount) 件紧急重要任务。"
        case .removed:
            alert.messageText = "已清理系统日历"
            alert.informativeText = "今天已经没有紧急重要任务，已删除之前导入的“\(summary.eventTitle)”。"
        case .skipped:
            alert.messageText = "无需导入"
            alert.informativeText = "今天没有紧急重要任务。"
        }

        alert.runModal()
    }

    @MainActor
    private func presentCalendarImportFailure(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "无法导入系统日历"
        alert.runModal()
    }

    @MainActor
    private func classifyTasks() async {
        guard let client = aiConfig.client else {
            await aiConfig.saveAndValidate()
            guard aiConfig.client != nil else { return }
            return await classifyTasks()
        }

        let pendingTasks = store.tasksNeedingAICategory()
        aiConfig.beginClassification()

        do {
            let categories = try await TaskAIService.classify(tasks: pendingTasks, client: client)
            store.applyAICategories(categories)
            aiConfig.finishClassification(count: categories.count)
        } catch {
            aiConfig.failClassification(error)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
