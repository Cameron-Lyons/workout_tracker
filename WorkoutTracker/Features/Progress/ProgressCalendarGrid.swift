import SwiftUI

struct AppCalendarMonthLayout: Equatable {
    struct DayEntry: Identifiable, Equatable {
        let id: Int
        let date: Date?
        let dayNumber: Int?
        let hasWorkout: Bool
    }

    let monthStart: Date
    let title: String
    let weekdaySymbols: [String]
    let dayEntries: [DayEntry]

    static func make(
        for displayedMonth: Date,
        workoutDays: Set<Date>,
        calendar: Calendar = .autoupdatingCurrent
    ) -> AppCalendarMonthLayout {
        let monthStart =
            calendar.date(
                from: calendar.dateComponents([.year, .month], from: displayedMonth)
            ) ?? displayedMonth
        let title = monthStart.formatted(.dateTime.month(.wide).year())
        let weekdaySymbols = rotatedWeekdaySymbols(for: calendar)

        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart),
            let firstWeekday = calendar.dateComponents([.weekday], from: monthStart).weekday
        else {
            return AppCalendarMonthLayout(
                monthStart: monthStart,
                title: title,
                weekdaySymbols: weekdaySymbols,
                dayEntries: []
            )
        }

        let normalizedLeading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dayEntries: [DayEntry] = []
        dayEntries.reserveCapacity(normalizedLeading + dayRange.count)

        for _ in 0..<normalizedLeading {
            dayEntries.append(
                DayEntry(
                    id: dayEntries.count,
                    date: nil,
                    dayNumber: nil,
                    hasWorkout: false
                )
            )
        }

        for dayNumber in dayRange {
            let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart)
            let normalizedDate = date.map { calendar.startOfDay(for: $0) }
            dayEntries.append(
                DayEntry(
                    id: dayEntries.count,
                    date: normalizedDate,
                    dayNumber: dayNumber,
                    hasWorkout: normalizedDate.map { workoutDays.contains($0) } ?? false
                )
            )
        }

        return AppCalendarMonthLayout(
            monthStart: monthStart,
            title: title,
            weekdaySymbols: weekdaySymbols,
            dayEntries: dayEntries
        )
    }

    private static func rotatedWeekdaySymbols(for calendar: Calendar) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else {
            return symbols
        }

        let startIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }
}

private struct AppCalendarDayCellView: View, Equatable {
    let entry: AppCalendarMonthLayout.DayEntry
    let isSelected: Bool
    let onSelect: () -> Void

    private let calendar = Calendar.autoupdatingCurrent

    nonisolated static func == (lhs: AppCalendarDayCellView, rhs: AppCalendarDayCellView) -> Bool {
        lhs.entry == rhs.entry && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Group {
            if let date = entry.date,
                let dayNumber = entry.dayNumber
            {
                Button {
                    onSelect()
                } label: {
                    VStack(spacing: 4) {
                        Text("\(dayNumber)")
                            .font(.subheadline.weight(entry.hasWorkout ? .semibold : .regular))
                            .foregroundStyle(textColor(for: date))

                        if isSelected {
                            Capsule()
                                .fill(AppColors.accentProgress)
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorWidth,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        } else if entry.hasWorkout {
                            Capsule()
                                .fill(AppColors.success)
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorWidth,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        } else if calendar.isDateInToday(date) {
                            Rectangle()
                                .fill(AppColors.warning)
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorWidth,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        } else {
                            Color.clear
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorWidth,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: ProgressDashboardMetrics.calendarCellHeight)
                }
                .buttonStyle(.plain)
                .disabled(!entry.hasWorkout)
                .accessibilityIdentifier("progress.calendar.day.\(date.formatted(.iso8601.year().month().day()))")
            } else {
                Color.clear
                    .frame(height: ProgressDashboardMetrics.calendarCellHeight)
            }
        }
    }

    private func textColor(for date: Date) -> Color {
        if isSelected {
            return AppColors.accentProgress
        }
        if entry.hasWorkout {
            return AppColors.textPrimary
        }
        if calendar.isDateInToday(date) {
            return AppColors.warning
        }
        return AppColors.textSecondary
    }
}

struct AppCalendarGrid: View {
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    @Binding var displayedMonth: Date
    let workoutDays: Set<Date>
    @Binding var selectedDay: Date?

    private let calendar = Calendar.autoupdatingCurrent

    @State private var monthLayout: AppCalendarMonthLayout

    init(displayedMonth: Binding<Date>, workoutDays: Set<Date>, selectedDay: Binding<Date?>) {
        self._displayedMonth = displayedMonth
        self.workoutDays = workoutDays
        self._selectedDay = selectedDay
        _monthLayout = State(
            initialValue: AppCalendarMonthLayout.make(
                for: displayedMonth.wrappedValue,
                workoutDays: workoutDays
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(monthLayout.title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(selectedDay?.formatted(date: .abbreviated, time: .omitted) ?? "Tap a highlighted day")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(Array(monthLayout.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthLayout.dayEntries) { entry in
                    AppCalendarDayCellView(
                        entry: entry,
                        isSelected: entry.date == selectedDay,
                        onSelect: {
                            selectedDay = entry.date == selectedDay ? nil : entry.date
                        }
                    )
                    .equatable()
                }
            }
            .padding(12)
        }
        .onChange(of: displayedMonth, initial: false) { _, newValue in
            monthLayout = AppCalendarMonthLayout.make(for: newValue, workoutDays: workoutDays)
        }
        .onChange(of: workoutDays, initial: false) { _, newValue in
            monthLayout = AppCalendarMonthLayout.make(for: displayedMonth, workoutDays: newValue)
        }
    }

    private func shiftMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: monthLayout.monthStart) else {
            return
        }

        displayedMonth = nextMonth
    }
}
