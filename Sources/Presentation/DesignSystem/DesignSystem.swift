import SwiftUI

// MARK: - App Theme

/// Central design system for the Sleep Tracker app
/// Provides consistent colors, gradients, typography, shadows, and spacing
enum AppTheme {

    // MARK: - Color Palette

    enum Colors {
        // Primary Brand Colors
        static let primary = Color("AccentColor", bundle: nil)
        static let primaryGradientStart = Color(hex: "667EEA")
        static let primaryGradientEnd = Color(hex: "764BA2")

        // Semantic Colors
        static let success = Color(hex: "10B981")
        static let successLight = Color(hex: "D1FAE5")
        static let warning = Color(hex: "F59E0B")
        static let warningLight = Color(hex: "FEF3C7")
        static let danger = Color(hex: "EF4444")
        static let dangerLight = Color(hex: "FEE2E2")
        static let info = Color(hex: "3B82F6")
        static let infoLight = Color(hex: "DBEAFE")

        // Sleep Stage Colors
        static let deepSleep = Color(hex: "4338CA")
        static let lightSleep = Color(hex: "818CF8")
        static let remSleep = Color(hex: "C084FC")
        static let awake = Color(hex: "FCD34D")

        // HRV Status Colors
        static let hrvExcellent = Color(hex: "059669")
        static let hrvGood = Color(hex: "10B981")
        static let hrvNormal = Color(hex: "3B82F6")
        static let hrvLow = Color(hex: "F59E0B")
        static let hrvPoor = Color(hex: "EF4444")

        // Surface Colors
        static let cardBackground = Color(UIColor.systemBackground)
        static let cardBackgroundElevated = Color(UIColor.secondarySystemBackground)
        static let cardBackgroundTertiary = Color(UIColor.tertiarySystemBackground)

        // Text Colors
        static let textPrimary = Color(UIColor.label)
        static let textSecondary = Color(UIColor.secondaryLabel)
        static let textTertiary = Color(UIColor.tertiaryLabel)
    }

    // MARK: - Gradients

    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.primaryGradientStart, Colors.primaryGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let sleep = LinearGradient(
            colors: [Color(hex: "1E1B4B"), Color(hex: "312E81")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let sunrise = LinearGradient(
            colors: [Color(hex: "FCD34D"), Color(hex: "F97316")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let recovery = LinearGradient(
            colors: [Color(hex: "059669"), Color(hex: "10B981")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let health = LinearGradient(
            colors: [Color(hex: "EC4899"), Color(hex: "EF4444")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let calm = LinearGradient(
            colors: [Color(hex: "06B6D4"), Color(hex: "3B82F6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let cardGloss = LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static func scoreGradient(for score: Int) -> LinearGradient {
            switch score {
            case 85...:
                return LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .top, endPoint: .bottom)
            case 70..<85:
                return LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")], startPoint: .top, endPoint: .bottom)
            case 50..<70:
                return LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "D97706")], startPoint: .top, endPoint: .bottom)
            default:
                return LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "DC2626")], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    // MARK: - Shadows

    enum Shadows {
        static let small = ShadowStyle(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
        static let glow = ShadowStyle(color: Colors.primaryGradientStart.opacity(0.3), radius: 16, x: 0, y: 0)

        static func colored(_ color: Color, intensity: Double = 0.3) -> ShadowStyle {
            ShadowStyle(color: color.opacity(intensity), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 15, weight: .medium, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

        // Metric Displays
        static let metricLarge = Font.system(size: 56, weight: .bold, design: .rounded)
        static let metricMedium = Font.system(size: 36, weight: .bold, design: .rounded)
        static let metricSmall = Font.system(size: 24, weight: .bold, design: .rounded)
        static let metricUnit = Font.system(size: 14, weight: .medium, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 100
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    func premiumCard(padding: CGFloat = AppTheme.Spacing.lg) -> some View {
        modifier(PremiumCardModifier(padding: padding))
    }

    func glassCard(padding: CGFloat = AppTheme.Spacing.lg) -> some View {
        modifier(GlassCardModifier(padding: padding))
    }

    func gradientCard(_ gradient: LinearGradient, padding: CGFloat = AppTheme.Spacing.lg) -> some View {
        modifier(GradientCardModifier(gradient: gradient, padding: padding))
    }

    func applyShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }

    func pulsingGlow(_ color: Color, isActive: Bool = true) -> some View {
        modifier(PulsingGlowModifier(color: color, isActive: isActive))
    }
}

// MARK: - Premium Card Modifier

struct PremiumCardModifier: ViewModifier {
    let padding: CGFloat
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0), lineWidth: 1)
                    )
            )
            .applyShadow(colorScheme == .dark ? AppTheme.Shadows.small : AppTheme.Shadows.medium)
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    let padding: CGFloat
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - Gradient Card Modifier

struct GradientCardModifier: ViewModifier {
    let gradient: LinearGradient
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(AppTheme.Gradients.cardGloss)
                    )
            )
            .applyShadow(AppTheme.Shadows.medium)
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.2),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                        .mask(content)
                    }
                }
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulsing Glow Modifier

struct PulsingGlowModifier: ViewModifier {
    let color: Color
    let isActive: Bool
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(isGlowing ? 0.6 : 0.2) : .clear, radius: isGlowing ? 12 : 4)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Gradients.primary)
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = AppTheme.Colors.info) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.subheadline)
            .foregroundColor(color)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(color.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.subheadline)
            .foregroundColor(.white)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Convenience Button Extensions

extension Button {
    func primaryStyle() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    func secondaryStyle(color: Color = AppTheme.Colors.info) -> some View {
        buttonStyle(SecondaryButtonStyle(color: color))
    }

    func glassStyle() -> some View {
        buttonStyle(GlassButtonStyle())
    }
}
