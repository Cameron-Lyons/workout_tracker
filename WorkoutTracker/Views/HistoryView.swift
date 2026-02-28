import Charts
import SwiftUI

private struct LiftProgressPoint: Identifiable {
    let sessionID: UUID
    let date: Date
    let topWeight: Double

    var id: UUID { sessionID }
}

struct HistoryView: View {
    private enum Constants {
        static let weekDayCount = 7
        static let sessionEntrySpacing: CGFloat = 6
        static let sessionHeaderSpacing: CGFloat = 2
        static let calendarSectionSpacing: CGFloat = 12
        static let calendarGridColumnSpacing: CGFloat = 4
        static let calendarGridRowSpacing: CGFloat = 8
        static let calendarDayInnerSpacing: CGFloat = 3
        static let calendarDayMarkerSize: CGFloat = 6
        static let calendarDayMinHeight: CGFloat = 42
        static let calendarDayCornerRadius: CGFloat = 8
        static let selectedDayOpacity = 0.2
        static let todayOutlineOpacity = 0.7
        static let todayOutlineWidth: CGFloat = 1
        static let calendarSectionVerticalPadding: CGFloat = 4
        static let chartHeight: CGFloat = 220
        static let chartDesiredTickCount = 4
    }

    @EnvironmentObject private var store: WorkoutStore
    @State private var selectedExerciseName = ""
    @State private var selectedCalendarDay: Date?
    @State private var displayedMonth = Date()
    @State private var hasInitializedCalendarMonth = false

    var body: some View {
        NavigationStack {
            Group {
                if store.workoutHistory.isEmpty {
                    ContentUnavailableView(
                        "No Logged Workouts",
                        systemImage: "calendar.badge.clock",
                        description: Text("Your completed workouts will appear here.")
                    )
                } else {
                    List {
                        calendarSection
                        progressSection

                        if filteredSessions.isEmpty {
                            Section("Logged Sessions") {
                                Text("No workouts match the selected date.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredSessions) { session in
                                Section {
                                    ForEach(session.entries) { entry in
                                        VStack(alignment: .leading, spacing: Constants.sessionEntrySpacing) {
                                            Text(entry.exerciseName)
                                                .font(.subheadline.weight(.semibold))

                                            if entry.sets.isEmpty {
                                                Text("No sets logged")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                                                    HStack {
                                                        Text("Set \(index + 1)")
                                                            .foregroundStyle(.secondary)
                                                        Spacer()
                                                        Text(setSummary(set))
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                } header: {
                                    VStack(alignment: .leading, spacing: Constants.sessionHeaderSpacing) {
                                        Text(session.routineName)
                                        if let context = session.programContext, !context.isEmpty {
                                            Text(context)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                syncExerciseSelection()
                syncCalendarState()
            }
            .onChange(of: store.liftHistory) { _, _ in
                syncExerciseSelection()
            }
            .onChange(of: store.workoutHistory) { _, _ in
                syncCalendarState()
            }
        }
    }

    private var trackedExercises: [String] {
        Array(Set(store.liftHistory.map(\.exerciseName))).sorted()
    }

    private var selectedExerciseBinding: Binding<String> {
        Binding(
            get: {
                if trackedExercises.contains(selectedExerciseName) {
                    return selectedExerciseName
                }
                return trackedExercises.first ?? ""
            },
            set: { newValue in
                selectedExerciseName = newValue
            }
        )
    }

    private var calendar: Calendar {
        .autoupdatingCurrent
    }

    private var workoutDays: Set<Date> {
        Set(store.workoutHistory.map { calendar.startOfDay(for: $0.performedAt) })
    }

    private var filteredSessions: [WorkoutSession] {
        guard let selectedCalendarDay else { return store.workoutHistory }
        return store.workoutHistory.filter { calendar.isDate($0.performedAt, inSameDayAs: selectedCalendarDay) }
    }

    private var displayedMonthStart: Date {
        calendar.startOfMonth(for: displayedMonth)
    }

    private var monthBounds: (earliest: Date, latest: Date)? {
        guard let earliestDay = workoutDays.min(),
              let latestDay = workoutDays.max() else {
            return nil
        }

        return (
            earliest: calendar.startOfMonth(for: earliestDay),
            latest: calendar.startOfMonth(for: latestDay)
        )
    }

    private var canNavigateToPreviousMonth: Bool {
        guard let monthBounds else { return false }
        return displayedMonthStart > monthBounds.earliest
    }

    private var canNavigateToNextMonth: Bool {
        guard let monthBounds else { return false }
        return displayedMonthStart < monthBounds.latest
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        return (0..<symbols.count).map { symbols[(startIndex + $0) % symbols.count] }
    }

    private var monthGridDates: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthStart),
              let days = calendar.range(of: .day, in: .month, for: displayedMonthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingSlots = (firstWeekday - calendar.firstWeekday + Constants.weekDayCount) % Constants.weekDayCount
        var gridDates = Array(repeating: Date?.none, count: leadingSlots)

        for day in days {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                gridDates.append(date)
            }
        }

        while gridDates.count % Constants.weekDayCount != 0 {
            gridDates.append(nil)
        }

        return gridDates
    }

    private var monthTitle: String {
        displayedMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var calendarSection: some View {
        Section("Workout Calendar") {
            VStack(spacing: Constants.calendarSectionSpacing) {
                HStack {
                    Button {
                        shiftDisplayedMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canNavigateToPreviousMonth)

                    Spacer()

                    Text(monthTitle)
                        .font(.headline)

                    Spacer()

                    Button {
                        shiftDisplayedMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canNavigateToNextMonth)
                }

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: Constants.calendarGridColumnSpacing),
                        count: Constants.weekDayCount
                    ),
                    spacing: Constants.calendarGridRowSpacing
                ) {
                    ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, date in
                        if let date {
                            calendarDayCell(for: date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: Constants.calendarDayMinHeight)
                        }
                    }
                }

                if let selectedCalendarDay {
                    HStack(alignment: .firstTextBaseline) {
                        Text(
                            "Showing \(filteredSessions.count) workout\(filteredSessions.count == 1 ? "" : "s") on \(selectedCalendarDay.formatted(date: .abbreviated, time: .omitted))."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button("Show All") {
                            self.selectedCalendarDay = nil
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else {
                    Text("Tap a marked day to filter sessions by date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, Constants.calendarSectionVerticalPadding)
        }
    }

    private func calendarDayCell(for date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        let hasWorkout = workoutDays.contains(normalizedDate)
        let isSelected = selectedCalendarDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedCalendarDay = normalizedDate
        } label: {
            VStack(spacing: Constants.calendarDayInnerSpacing) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(hasWorkout ? .semibold : .regular))
                    .foregroundStyle(hasWorkout ? Color.primary : Color.secondary)

                Circle()
                    .fill(hasWorkout ? (isSelected ? Color.accentColor : Color.secondary) : Color.clear)
                    .frame(width: Constants.calendarDayMarkerSize, height: Constants.calendarDayMarkerSize)
            }
            .frame(maxWidth: .infinity, minHeight: Constants.calendarDayMinHeight)
            .background {
                RoundedRectangle(cornerRadius: Constants.calendarDayCornerRadius)
                    .fill(isSelected ? Color.accentColor.opacity(Constants.selectedDayOpacity) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Constants.calendarDayCornerRadius)
                    .stroke(
                        isToday ? Color.accentColor.opacity(Constants.todayOutlineOpacity) : Color.clear,
                        lineWidth: Constants.todayOutlineWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasWorkout)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasWorkout ? "Workout logged" : "No workout logged")
    }

    private func shiftDisplayedMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonthStart) else {
            return
        }

        displayedMonth = calendar.startOfMonth(for: nextMonth)
    }

    private var progressPoints: [LiftProgressPoint] {
        guard !selectedExerciseName.isEmpty else { return [] }

        let records = store.liftHistory.filter { $0.exerciseName == selectedExerciseName }
        let groupedBySession = Dictionary(grouping: records, by: \.sessionID)

        return groupedBySession.compactMap { sessionID, groupedRecords in
            guard let date = groupedRecords.map(\.performedAt).max(),
                  let topWeight = groupedRecords.compactMap(\.weight).max() else {
                return nil
            }

            return LiftProgressPoint(sessionID: sessionID, date: date, topWeight: topWeight)
        }
        .sorted { $0.date < $1.date }
    }

    private var trendSummary: String? {
        guard let firstPoint = progressPoints.first else { return nil }
        let latestPoint = progressPoints.last ?? firstPoint
        let latestWeight = WeightFormatter.displayString(latestPoint.topWeight)

        if progressPoints.count < 2 {
            return "Latest top set: \(latestWeight) lb on \(latestPoint.date.formatted(date: .abbreviated, time: .omitted))."
        }

        let change = latestPoint.topWeight - firstPoint.topWeight
        let changePrefix = change >= 0 ? "+" : "-"
        let absoluteChange = WeightFormatter.displayString(abs(change))

        return "Change since first logged workout: \(changePrefix)\(absoluteChange) lb (\(firstPoint.date.formatted(date: .abbreviated, time: .omitted)) -> \(latestPoint.date.formatted(date: .abbreviated, time: .omitted)))."
    }

    private var progressSection: some View {
        Section("Progress Over Time") {
            if trackedExercises.isEmpty {
                Text("Log sets with weight to see progress over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Exercise", selection: selectedExerciseBinding) {
                    ForEach(trackedExercises, id: \.self) { exerciseName in
                        Text(exerciseName).tag(exerciseName)
                    }
                }
                .pickerStyle(.menu)

                if progressPoints.isEmpty {
                    Text("No weighted sets for this exercise yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(progressPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Top Weight (lb)", point.topWeight)
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Top Weight (lb)", point.topWeight)
                        )
                    }
                    .frame(height: Constants.chartHeight)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: Constants.chartDesiredTickCount))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }

                    if let trendSummary {
                        Text(trendSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func setSummary(_ set: ExerciseSet) -> String {
        let weightText: String
        if let weight = set.weight {
            weightText = WeightFormatter.displayString(weight)
        } else {
            weightText = "-"
        }

        let repsText = set.reps.map(String.init) ?? "-"
        return "\(weightText) x \(repsText)"
    }

    private func syncExerciseSelection() {
        let options = trackedExercises
        guard !options.isEmpty else {
            selectedExerciseName = ""
            return
        }

        if options.contains(selectedExerciseName) == false {
            selectedExerciseName = options[0]
        }
    }

    private func syncCalendarState() {
        if hasInitializedCalendarMonth == false {
            if let latestWorkoutDate = store.workoutHistory.first?.performedAt {
                displayedMonth = calendar.startOfMonth(for: latestWorkoutDate)
            } else {
                displayedMonth = calendar.startOfMonth(for: Date())
            }
            hasInitializedCalendarMonth = true
        }

        let availableDays = workoutDays
        guard !availableDays.isEmpty else {
            selectedCalendarDay = nil
            return
        }

        if let selectedCalendarDay {
            let normalizedSelectedDate = calendar.startOfDay(for: selectedCalendarDay)
            self.selectedCalendarDay = availableDays.contains(normalizedSelectedDate) ? normalizedSelectedDate : nil
        }

        if let monthBounds {
            if displayedMonthStart < monthBounds.earliest {
                displayedMonth = monthBounds.earliest
            } else if displayedMonthStart > monthBounds.latest {
                displayedMonth = monthBounds.latest
            }
        }
    }
}

private extension Calendar {
    func startOfMonth(for value: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: value)) ?? startOfDay(for: value)
    }
}
