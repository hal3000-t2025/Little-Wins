import SwiftUI

struct AISettingsView: View {
    @Environment(AIConfigStore.self) private var aiConfig

    var body: some View {
        @Bindable var aiConfig = aiConfig

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DeepSeek 设置")
                    .font(.largeTitle.weight(.semibold))
                Text("不填写或连接失败时，AI 功能保持关闭，其他功能照常使用。")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.headline)
                SecureField("sk-...", text: $aiConfig.apiKeyInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("模型")
                    .font(.headline)
                Picker("模型", selection: $aiConfig.model) {
                    Text("deepseek-v4-flash").tag("deepseek-v4-flash")
                    Text("deepseek-v4-pro").tag("deepseek-v4-pro")
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        await aiConfig.saveAndValidate()
                    }
                } label: {
                    Label(aiConfig.isChecking ? "验证中" : "保存并测试", systemImage: "checkmark.shield")
                }
                .disabled(aiConfig.isChecking || aiConfig.isClassifying)

                Button(role: .destructive) {
                    aiConfig.clear()
                } label: {
                    Label("清除", systemImage: "trash")
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(aiConfig.isEnabled ? .green : .secondary)
                    .frame(width: 9, height: 9)
                Text(aiConfig.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
    }
}
