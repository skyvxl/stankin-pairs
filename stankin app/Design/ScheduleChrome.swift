import SwiftUI

enum ScheduleSurfaceStyle {
    case card
    case elevated
    case glass
}

enum ScheduleBackdropStyle {
    case canvas
    case sheet
}

struct ScheduleBackdrop: View {
    var style: ScheduleBackdropStyle = .canvas

    var body: some View {
        Color(uiColor: backgroundColor)
        .ignoresSafeArea()
    }

    private var backgroundColor: UIColor {
        switch style {
        case .canvas:
            return .systemBackground
        case .sheet:
            return .systemGroupedBackground
        }
    }
}

struct SchedulePanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let style: ScheduleSurfaceStyle
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    init(
        style: ScheduleSurfaceStyle = .card,
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(
            SchedulePanelStyleModifier(
                style: style,
                shape: shape,
                colorScheme: colorScheme
            )
        )
    }
}

struct SchedulePill: View {
    let title: String
    let systemImage: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }

            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.75)
        }
    }
}

struct ScheduleLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)

                Text("Загружаю расписание…")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .glassEffect(
                .regular.tint(.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct SheetToolbarTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.body.weight(.semibold))
    }
}

struct SheetToolbarIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct SchedulePanelStyleModifier<S: InsettableShape>: ViewModifier {
    let style: ScheduleSurfaceStyle
    let shape: S
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content
                .background {
                    shape
                        .fill(fillColor)
                        .background(.regularMaterial, in: shape)
                }
                .overlay {
                    shape
                        .strokeBorder(strokeColor, lineWidth: 0.8)
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07),
                    radius: colorScheme == .dark ? 26 : 20,
                    x: 0,
                    y: 12
                )

        case .elevated:
            content
                .background {
                    shape
                        .fill(fillColor.opacity(colorScheme == .dark ? 0.92 : 0.98))
                        .background(.thinMaterial, in: shape)
                }
                .overlay {
                    shape
                        .strokeBorder(strokeColor.opacity(1.15), lineWidth: 0.9)
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.09),
                    radius: colorScheme == .dark ? 28 : 22,
                    x: 0,
                    y: 14
                )

        case .glass:
            content
                .glassEffect(
                    .regular.tint(.white.opacity(colorScheme == .dark ? 0.04 : 0.08)),
                    in: shape
                )
        }
    }

    private var fillColor: Color {
        Color(uiColor: colorScheme == .dark ? .secondarySystemBackground : .secondarySystemGroupedBackground)
    }

    private var strokeColor: Color {
        if colorScheme == .dark {
            return .white.opacity(0.06)
        }

        return Color.black.opacity(0.05)
    }
}
