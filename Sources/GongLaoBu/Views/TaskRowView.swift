import SwiftUI

struct TaskRowView: View {
    @Environment(AppState.self) private var appState

    var task: TaskItem
    var isSelected = false
    var showsQuadrantBadge = true
    var onSelect: (() -> Void)?
    var onToggle: () -> Void
    var onRename: ((String) -> Void)?
    var onDelete: (() -> Void)?

    @FocusState private var isTitleFocused: Bool
    @State private var draftTitle = ""
    @State private var isEditing = false
    @State private var isHovering = false

    private var accentColor: Color {
        task.quadrant?.tintColor ?? .accentColor
    }

    private var needsAttention: Bool {
        !task.isCompleted && task.carryOverCount >= 3
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? .green : accentColor)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "取消完成" : "完成")

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    titleView
                        .layoutPriority(1)

                    if let aiCategory = task.aiCategory, !aiCategory.isEmpty, !isEditing {
                        BadgeView(text: aiCategory, color: .teal)
                    }
                }

                if hasSecondaryMetadata {
                    HStack(spacing: 6) {
                        if showsQuadrantBadge, let quadrant = task.quadrant {
                            BadgeView(text: quadrant.title, color: quadrant.tintColor)
                        }

                        if task.carryOverCount > 0 {
                            BadgeView(text: carryOverText, color: needsAttention ? .red : .purple)
                        }

                        if let completedAt = task.completedAt {
                            Text(completedAt.glbTimeTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                if onRename != nil {
                    MutedIconButton(systemName: "pencil", help: "编辑内容") {
                        beginEditing()
                    }
                }

                if let onDelete {
                    MutedIconButton(systemName: "trash", help: "删除", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .frame(width: 56, alignment: .trailing)
            .opacity(isHovering || isSelected || isEditing ? 1 : 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: GLBTheme.radius)
                .stroke(rowStrokeColor, lineWidth: rowStrokeWidth)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect?()
        }
        .onTapGesture(count: 2) {
            beginEditing()
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused {
                commitRename()
            }
        }
        .onChange(of: task.title) { _, newTitle in
            if !isEditing {
                draftTitle = newTitle
            }
        }
        .onChange(of: appState.editTaskRequestID) { _, requestedID in
            guard requestedID == task.id else { return }
            beginEditing()
            appState.clearEditTaskRequest()
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if isEditing {
            TextField("任务", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.callout.weight(.semibold))
                .focused($isTitleFocused)
                .onSubmit(commitRename)
        } else {
            Text(task.title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : titleColor)
        }
    }

    private var titleColor: Color {
        if needsAttention {
            return .red
        }
        return task.quadrant == .urgentImportant ? .red : .primary
    }

    private var rowBackground: Color {
        if needsAttention {
            return .red.opacity(0.07)
        }
        if task.isCompleted {
            return .green.opacity(0.045)
        }
        return Color.primary.opacity(0.045)
    }

    private var rowStrokeColor: Color {
        if isSelected {
            return .accentColor
        }
        if needsAttention {
            return .red.opacity(0.45)
        }
        if task.isCompleted {
            return .green.opacity(0.18)
        }
        return Color.primary.opacity(0.06)
    }

    private var rowStrokeWidth: CGFloat {
        if isSelected {
            return 2
        }
        return needsAttention ? 1 : 0
    }

    private var carryOverText: String {
        if needsAttention {
            return "延期 \(task.carryOverCount)，建议拆小"
        }
        return "延期 \(task.carryOverCount)"
    }

    private var hasSecondaryMetadata: Bool {
        (showsQuadrantBadge && task.quadrant != nil) || task.carryOverCount > 0 || task.completedAt != nil
    }

    private func beginEditing() {
        guard onRename != nil else { return }
        draftTitle = task.title
        isEditing = true
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    private func commitRename() {
        guard isEditing else { return }
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            onRename?(trimmed)
        }
        isEditing = false
        isTitleFocused = false
    }
}

struct TaskChipView: View {
    var task: TaskItem

    var body: some View {
        HStack(spacing: 6) {
            Text(task.title)
                .lineLimit(1)
                .font(.callout.weight(.medium))

            if task.carryOverCount > 0 {
                Text("\(task.carryOverCount)")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(task.carryOverCount >= 3 ? .red : .purple, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: GLBTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: GLBTheme.radius)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct BadgeView: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
