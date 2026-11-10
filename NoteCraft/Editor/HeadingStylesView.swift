import SwiftUI

/// The popover content of the heading tool: body text and the six heading levels, each in its own size like in the preview.
struct HeadingStylesView: View {
    let currentLevel: Int
    let choose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0...6, id: \.self) { level in
                HeadingStyleRow(level: level, isCurrent: level == currentLevel) {
                    choose(level)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 200)
    }
}

private struct HeadingStyleRow: View {
    let level: Int
    let isCurrent: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var title: String {
        level == 0 ? L10n.Menu.bodyText : L10n.Menu.headingLevel(level)
    }

    private var font: Font {
        switch level {
        case 1: .system(size: 22, weight: .semibold)
        case 2: .system(size: 18, weight: .semibold)
        case 3: .system(size: 15, weight: .semibold)
        case 4: .system(size: 13, weight: .semibold)
        case 5, 6: .system(size: 12, weight: .semibold)
        default: .system(size: 13)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(isCurrent ? 1 : 0)
                    .accessibilityHidden(true)
                Text(title)
                    .font(font)
                    .foregroundStyle(level == 6 ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
