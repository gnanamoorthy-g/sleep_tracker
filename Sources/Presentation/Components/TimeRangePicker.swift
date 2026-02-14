import SwiftUI

/// Time range options similar to Apple Health
enum TimeRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    /// Whether this range shows intraday (hourly) data vs daily aggregated data
    var isIntraday: Bool {
        self == .day
    }

    /// Number of days for this range (nil means all data)
    var days: Int? {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        case .all: return nil
        }
    }

    /// Start date for this range (calendar-aligned)
    func startDate(from endDate: Date = Date()) -> Date? {
        guard let days = days else { return nil }
        let calendar = Calendar.current
        if self == .day {
            // For 1D, start at beginning of today
            return calendar.startOfDay(for: endDate)
        }
        let startOfToday = calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday)
    }

    /// End date
    var endDate: Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
    }

    /// Appropriate date format for x-axis labels
    var dateFormat: Date.FormatStyle {
        switch self {
        case .day:
            return .dateTime.hour()
        case .week:
            return .dateTime.weekday(.abbreviated).day()
        case .month:
            return .dateTime.month(.abbreviated).day()
        case .threeMonths, .sixMonths:
            return .dateTime.month(.abbreviated).day()
        case .year, .all:
            return .dateTime.month(.abbreviated)
        }
    }

    /// Desired tick count for x-axis
    var desiredAxisMarks: Int {
        switch self {
        case .day: return 6
        case .week: return 7
        case .month: return 6
        case .threeMonths: return 4
        case .sixMonths: return 6
        case .year: return 6
        case .all: return 5
        }
    }
}

/// Apple Health-style horizontal time range picker
struct TimeRangePicker: View {
    @Binding var selectedRange: TimeRange
    var availableRanges: [TimeRange] = TimeRange.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableRanges) { range in
                    TimeRangeButton(
                        title: range.rawValue,
                        isSelected: selectedRange == range
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRange = range
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Filtering Extension

extension Array where Element == DailyHRVDataPoint {
    /// Filter data points by time range
    func filtered(by range: TimeRange) -> [DailyHRVDataPoint] {
        guard let startDate = range.startDate() else {
            return self // Return all for .all range
        }
        return self.filter { $0.date >= startDate }
    }
}

#Preview {
    VStack {
        TimeRangePicker(selectedRange: .constant(.week))
        TimeRangePicker(
            selectedRange: .constant(.month),
            availableRanges: [.week, .month, .threeMonths, .year]
        )
    }
    .padding()
}
