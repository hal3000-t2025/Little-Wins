import Foundation
import Observation

@MainActor
@Observable
final class AIConfigStore {
    var apiKeyInput: String
    var model = "deepseek-v4-flash"
    var isEnabled = false
    var isChecking = false
    var isClassifying = false
    var statusMessage: String

    private var validatedAPIKey: String?

    init() {
        let savedKey = KeychainService.loadDeepSeekAPIKey() ?? ""
        self.apiKeyInput = savedKey
        self.statusMessage = savedKey.isEmpty ? "未配置 DeepSeek，AI 功能保持关闭。" : "已读取 DeepSeek key，等待连通验证。"
    }

    var canUseAI: Bool {
        isEnabled && validatedAPIKey != nil && !isChecking && !isClassifying
    }

    var client: DeepSeekClient? {
        guard let validatedAPIKey, isEnabled else { return nil }
        return DeepSeekClient(apiKey: validatedAPIKey, model: model)
    }

    func validateSavedKeyIfNeeded() async {
        guard !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard validatedAPIKey == nil else { return }
        await saveAndValidate()
    }

    func saveAndValidate() async {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            disable(message: "未配置 DeepSeek，AI 功能保持关闭。")
            try? KeychainService.deleteDeepSeekAPIKey()
            return
        }

        isChecking = true
        statusMessage = "正在验证 DeepSeek 连接..."
        defer { isChecking = false }

        do {
            try await DeepSeekClient(apiKey: key, model: model).validate()
            try KeychainService.saveDeepSeekAPIKey(key)
            validatedAPIKey = key
            isEnabled = true
            statusMessage = "DeepSeek 已启用。"
        } catch {
            disable(message: "DeepSeek 连接失败，AI 功能保持关闭：\(error.localizedDescription)")
        }
    }

    func clear() {
        apiKeyInput = ""
        try? KeychainService.deleteDeepSeekAPIKey()
        disable(message: "已清除 DeepSeek key，AI 功能关闭。")
    }

    func beginClassification() {
        isClassifying = true
        statusMessage = "正在自动分类事项..."
    }

    func finishClassification(count: Int) {
        isClassifying = false
        if count == 0 {
            statusMessage = "没有需要分类的事项。"
        } else {
            statusMessage = "已自动分类 \(count) 件事项。"
        }
    }

    func failClassification(_ error: Error) {
        isClassifying = false
        statusMessage = "自动分类失败，现有功能不受影响：\(error.localizedDescription)"
    }

    private func disable(message: String) {
        validatedAPIKey = nil
        isEnabled = false
        statusMessage = message
    }
}
