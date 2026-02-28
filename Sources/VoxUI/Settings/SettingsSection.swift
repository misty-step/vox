import SwiftUI

enum SettingsSectionProminence {
    case primary
    case secondary

    var fillColor: Color {
        switch self {
        case .primary:
            return Color(nsColor: .controlBackgroundColor)
        case .secondary:
            return Color(nsColor: .windowBackgroundColor)
        }
    }

    var borderColor: Color {
        switch self {
        case .primary:
            return Color.accentColor.opacity(0.25)
        case .secondary:
            return Color.primary.opacity(0.10)
        }
    }

    var iconColor: Color {
        switch self {
        case .primary:
            return Color.accentColor
        case .secondary:
            return Color.secondary
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .primary:
            return Color.accentColor.opacity(0.14)
        case .secondary:
            return Color.primary.opacity(0.07)
        }
    }
}

struct SettingsSection<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let prominence: SettingsSectionProminence
    private let content: Content

    init(
        title: String,
        systemImage: String,
        prominence: SettingsSectionProminence = .secondary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominence = prominence
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(prominence.iconColor)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(prominence.iconBackgroundColor)
                    )
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 0)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(prominence.fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(prominence.borderColor, lineWidth: 1)
        )
    }
}
