import SwiftUI

extension TaskQuadrant {
    var tintColor: Color {
        switch self {
        case .urgentImportant:
            .red
        case .importantNotUrgent:
            .blue
        case .urgentNotImportant:
            .orange
        case .neither:
            .gray
        }
    }

    var panelFill: Color {
        tintColor.opacity(0.045)
    }
}
