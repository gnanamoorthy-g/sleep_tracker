import SwiftUI

// MARK: - Premium Metric Card

/// A polished metric card with animated value display
struct PremiumMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    var trend: TrendDirection?
    var subtitle: String?
    var isAnimated: Bool = true

    enum TrendDirection {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return AppTheme.Colors.success
            case .down: return AppTheme.Colors.danger
            case .stable: return AppTheme.Colors.info
            }
        }
    }

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Header
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color.gradient)

                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(trend.color)
                }
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xxs) {
                Text(value)
                    .font(AppTheme.Typography.metricSmall)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(AppTheme.Typography.metricUnit)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
        .onAppear {
            guard isAnimated else {
                appeared = true
                return
            }
            withAnimation(AppTheme.Animation.spring.delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Circular Progress Ring

/// A premium circular progress indicator with gradient and animation
struct CircularProgressRing: View {
    let progress: Double
    let gradient: LinearGradient
    var lineWidth: CGFloat = 12
    var size: CGFloat = 120
    var showPercentage: Bool = true

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.15),
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            if showPercentage {
                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress * 100))")
                        .font(AppTheme.Typography.metricMedium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .contentTransition(.numericText())

                    Text("score")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .textCase(.uppercase)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Premium Status Badge

/// A polished status indicator badge
struct PremiumStatusBadge: View {
    let status: Status
    var size: Size = .medium

    enum Status {
        case connected, connecting, disconnected, active, inactive, warning, error

        var color: Color {
            switch self {
            case .connected, .active: return AppTheme.Colors.success
            case .connecting: return AppTheme.Colors.warning
            case .disconnected, .inactive: return AppTheme.Colors.textTertiary
            case .warning: return AppTheme.Colors.warning
            case .error: return AppTheme.Colors.danger
            }
        }

        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .disconnected: return "xmark.circle.fill"
            case .active: return "circle.fill"
            case .inactive: return "circle"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }

        var label: String {
            switch self {
            case .connected: return "Connected"
            case .connecting: return "Connecting"
            case .disconnected: return "Disconnected"
            case .active: return "Active"
            case .inactive: return "Inactive"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }
    }

    enum Size {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }

        var font: Font {
            switch self {
            case .small: return AppTheme.Typography.caption2
            case .medium: return AppTheme.Typography.caption
            case .large: return AppTheme.Typography.subheadline
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .large: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            }
        }
    }

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle()
                .fill(status.color)
                .frame(width: size.iconSize, height: size.iconSize)
                .overlay(
                    Circle()
                        .stroke(status.color.opacity(0.4), lineWidth: 2)
                        .scaleEffect(isAnimating && status == .connecting ? 1.5 : 1)
                        .opacity(isAnimating && status == .connecting ? 0 : 1)
                )

            Text(status.label)
                .font(size.font)
                .foregroundColor(status.color)
        }
        .padding(size.padding)
        .background(
            Capsule()
                .fill(status.color.opacity(0.12))
        )
        .onAppear {
            if status == .connecting {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Premium Section Header

/// A styled section header with optional action button
struct PremiumSectionHeader: View {
    let title: String
    var icon: String?
    var iconColor: Color = AppTheme.Colors.info
    var action: (() -> Void)?
    var actionLabel: String = "See All"

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor.gradient)
            }

            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()

            if let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                            .font(AppTheme.Typography.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.info)
                }
            }
        }
    }
}

// MARK: - Animated Heart Rate Display

/// A premium heart rate display with pulse animation
struct AnimatedHeartRateDisplay: View {
    let heartRate: Int
    var isActive: Bool = true

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.danger.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPulsing ? 1.15 : 1)
                    .opacity(isPulsing ? 0.5 : 1)

                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.Gradients.health)
                    .scaleEffect(isPulsing ? 1.1 : 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(heartRate)")
                    .font(AppTheme.Typography.metricMedium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .contentTransition(.numericText())

                Text("BPM")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .onAppear {
            guard isActive else { return }
            startPulseAnimation()
        }
        .onChange(of: isActive) { active in
            if active {
                startPulseAnimation()
            }
        }
    }

    private func startPulseAnimation() {
        let duration = heartRate > 0 ? 60.0 / Double(heartRate) : 1.0
        withAnimation(.easeInOut(duration: duration * 0.3).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

// MARK: - Premium Empty State

/// A polished empty state view with illustration
struct PremiumEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionLabel: String = "Get Started"
    var iconColor: Color = AppTheme.Colors.info

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(iconColor.gradient)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let action = action {
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(actionLabel)
                    }
                }
                .primaryStyle()
                .frame(maxWidth: 200)
            }
        }
        .padding(AppTheme.Spacing.xxxl)
    }
}

// MARK: - Signal Strength Indicator

/// A premium signal strength indicator
struct PremiumSignalStrength: View {
    let bars: Int
    var maxBars: Int = 4

    var color: Color {
        switch bars {
        case 4: return AppTheme.Colors.success
        case 3: return AppTheme.Colors.success
        case 2: return AppTheme.Colors.warning
        default: return AppTheme.Colors.danger
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxBars, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level <= bars ? color : Color.gray.opacity(0.2))
                    .frame(width: 4, height: CGFloat(level * 4 + 4))
            }
        }
    }
}

// MARK: - Premium Timer Display

/// A polished timer display for active sessions
struct PremiumTimerDisplay: View {
    let elapsed: TimeInterval
    var total: TimeInterval?
    var accentColor: Color = AppTheme.Colors.info
    var size: CGFloat = 80
    var showRemainingLabel: Bool = true

    private var lineWidth: CGFloat {
        size * 0.08 // 8% of size
    }

    private var fontSize: Font {
        if size >= 100 {
            return AppTheme.Typography.metricMedium
        } else if size >= 70 {
            return AppTheme.Typography.title3
        } else {
            return AppTheme.Typography.headline
        }
    }

    var progress: Double {
        guard let total = total, total > 0 else { return 0 }
        return min(elapsed / total, 1.0)
    }

    var formattedTime: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ZStack {
                // Background ring
                if total != nil {
                    Circle()
                        .stroke(accentColor.opacity(0.15), lineWidth: lineWidth)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                Text(formattedTime)
                    .font(fontSize)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(width: size, height: size)

            if showRemainingLabel, let total = total {
                Text("\(Int((1 - progress) * total / 60)):\(String(format: "%02d", Int((1 - progress) * total) % 60)) left")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Animated Loading Dots

/// Loading indicator with animated dots
struct LoadingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppTheme.Colors.info)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Premium Divider

/// A styled divider with optional label
struct PremiumDivider: View {
    var label: String?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            if let label = label {
                Text(label)
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .textCase(.uppercase)

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Preview Provider

#Preview("Premium Components") {
    ScrollView {
        VStack(spacing: 24) {
            PremiumMetricCard(
                title: "Heart Rate",
                value: "72",
                unit: "BPM",
                icon: "heart.fill",
                color: .red,
                trend: .stable,
                subtitle: "Resting"
            )

            CircularProgressRing(
                progress: 0.85,
                gradient: AppTheme.Gradients.recovery
            )

            PremiumStatusBadge(status: .connected)

            PremiumSectionHeader(
                title: "Quick Stats",
                icon: "chart.bar.fill",
                action: {}
            )

            AnimatedHeartRateDisplay(heartRate: 65)

            PremiumEmptyState(
                icon: "moon.zzz.fill",
                title: "No Sleep Data",
                message: "Start tracking your sleep to see insights here.",
                action: {},
                actionLabel: "Start Tracking"
            )

            PremiumTimerDisplay(elapsed: 125, total: 180)

            LoadingDots()
        }
        .padding()
    }
}
