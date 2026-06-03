import SwiftUI

enum GLBTheme {
    static let radius: CGFloat = 8
    static let red = Color(red: 0.76, green: 0.16, blue: 0.10)
    static let gold = Color(red: 0.92, green: 0.66, blue: 0.18)
    static let pagePadding: CGFloat = 24
}

struct PageHeader<Accessory: View>: View {
    var title: String
    var subtitle: String
    var count: Int?
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        subtitle: String,
        count: Int? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            accessory
        }
        .padding(.top, 4)
    }
}

extension PageHeader where Accessory == EmptyView {
    init(title: String, subtitle: String, count: Int? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.accessory = EmptyView()
    }
}

struct PanelSurface<Content: View>: View {
    var tint: Color?
    var content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: GLBTheme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: GLBTheme.radius)
                    .stroke((tint ?? Color.primary).opacity(tint == nil ? 0.10 : 0.28), lineWidth: 1)
            }
    }
}

struct IconBadge: View {
    var systemName: String
    var color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: GLBTheme.radius))
    }
}

struct MutedIconButton: View {
    var systemName: String
    var help: String
    var role: ButtonRole?
    var action: () -> Void

    init(systemName: String, help: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.systemName = systemName
        self.help = help
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(role == .destructive ? .red : .secondary)
        .help(help)
    }
}
