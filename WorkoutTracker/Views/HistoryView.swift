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
        static let chartHeight: CGFloat = 220
        static let chartDesiredTickCount = 4
    }

    @EnvironmentObject private var store: WorkoutStore
    @AppStorage(WeightUnit.preferenceKey) private var weightUnitRawValue = WeightUnit.pounds.rawValue
    @State private var selectedExerciseName = ""
    @State private var selectedCalendarDay: Date?
    @State private var displayedMonth = Date()
    @State private var hasInitializedCalendarMonth = false
    @State private var cachedWorkoutDays: Set<Date> = []
    @State private var cachedFilteredSessions: [WorkoutSession] = []
    @State private var cachedProgressPointsByExerciseName: [String: [LiftProgressPoint]] = [:]
#if DEBUG
    @State private var showBenchmarkAlert = false
    @State private var benchmarkSummary = ""
#endif

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRawValue) ?? .pounds
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if store.workoutHistory.isEmpty {
                        emptyState
                    } else {
                        let sessions = cachedFilteredSessions

                        List {
                            calendarSection(filteredSessionCount: sessions.count)
                            progressSection

                            if sessions.isEmpty {
                                Section("Logged Sessions") {
                                    Text("No workouts match the selected date.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .padding(14)
                                        .appSurface(cornerRadius: 14, shadow: false)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 8, trailing: 14))
                                        .listRowSeparator(.hidden)
                                }
                            } else {
                                ForEach(sessions) { session in
                                    Section {
                                        ForEach(session.entries) { entry in
                                            sessionEntryCard(entry)
                                                .scrollTransition(axis: .vertical) { content, phase in
                                                    content
                                                        .opacity(phase.isIdentity ? 1 : 0.84)
                                                        .scaleEffect(phase.isIdentity ? 1 : 0.985)
                                                }
                                                .listRowBackground(Color.clear)
                                                .listRowSeparator(.hidden)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                                        }
                                    } header: {
                                        sessionHeader(session)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("History")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                rebuildHistoryCaches()
                syncExerciseSelection()
                rebuildProgressPointsCache()
                syncCalendarState()
            }
            .onChange(of: store.liftHistory) { _, _ in
                syncExerciseSelection()
                rebuildProgressPointsCache()
            }
            .onChange(of: store.workoutHistory) { _, _ in
                rebuildHistoryCaches()
                syncCalendarState()
            }
            .onChange(of: selectedCalendarDay) { _, _ in
                updateFilteredSessions()
            }
            .onChange(of: weightUnitRawValue) { _, _ in
                rebuildProgressPointsCache()
            }
            .tint(AppColors.accent)
#if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Benchmark") {
                        benchmarkSummary = store.runHistoryQueryBenchmark()
                        showBenchmarkAlert = true
                    }
                }
            }
            .alert("History Query Benchmark", isPresented: $showBenchmarkAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(benchmarkSummary)
            }
#endif
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppColors.accent)

            Text("No Logged Workouts")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("Your completed workouts and progress trends will appear here.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .appSurface()
        .padding(.horizontal, 20)
    }

    private func sessionEntryCard(_ entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: Constants.sessionEntrySpacing) {
            Text(entry.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            if entry.sets.isEmpty {
                Text("No sets logged")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("Set \(index + 1)")
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(setSummary(set))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(14)
        .appSurface(cornerRadius: 14, shadow: false)
    }

    private func sessionHeader(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: Constants.sessionHeaderSpacing) {
            Text(session.routineName)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            if let context = session.programContext, !context.isEmpty {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .textCase(nil)
        .padding(.top, 16)
        .padding(.horizontal, 14)
    }

    private var trackedExercises: [String] {
        store.exerciseNamesWithLiftHistory
    }

    private func selectedExerciseBinding(options: [String]) -> Binding<String> {
        Binding(
            get: {
                if options.contains(selectedExerciseName) {
                    return selectedExerciseName
                }
                return options.first ?? ""
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
        cachedWorkoutDays
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

    private func calendarSection(filteredSessionCount: Int) -> some View {
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
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

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
                            .foregroundStyle(AppColors.textSecondary)
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
                            "Showing \(filteredSessionCount) workout\(filteredSessionCount == 1 ? "" : "s") on \(selectedCalendarDay.formatted(date: .abbreviated, time: .omitted))."
                        )
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                        Spacer()

                        Button("Show All") {
                            self.selectedCalendarDay = nil
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else {
                    Text("Tap a marked day to filter sessions by date.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .appSurface(cornerRadius: 16, shadow: false)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
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
                    .foregroundStyle(hasWorkout ? AppColors.textPrimary : AppColors.textSecondary)

                Circle()
                    .fill(hasWorkout ? (isSelected ? AppColors.accent : AppColors.textSecondary) : Color.clear)
                    .frame(width: Constants.calendarDayMarkerSize, height: Constants.calendarDayMarkerSize)
            }
            .frame(maxWidth: .infinity, minHeight: Constants.calendarDayMinHeight)
            .background {
                RoundedRectangle(cornerRadius: Constants.calendarDayCornerRadius)
                    .fill(isSelected ? AppColors.accent.opacity(Constants.selectedDayOpacity) : AppColors.surface.opacity(0.35))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Constants.calendarDayCornerRadius)
                    .stroke(
                        isToday ? AppColors.accentAlt.opacity(Constants.todayOutlineOpacity) : Color.clear,
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

    private func progressPoints(for exerciseName: String, unit: WeightUnit) -> [LiftProgressPoint] {
        guard !exerciseName.isEmpty else { return [] }

        let records = store.liftRecords(forExerciseName: exerciseName)
        var summaryBySessionID: [UUID: (date: Date, topWeightInStoredPounds: Double)] = [:]

        for record in records {
            guard let weight = record.weight else {
                continue
            }

            if var existing = summaryBySessionID[record.sessionID] {
                if record.performedAt > existing.date {
                    existing.date = record.performedAt
                }

                if weight > existing.topWeightInStoredPounds {
                    existing.topWeightInStoredPounds = weight
                }

                summaryBySessionID[record.sessionID] = existing
            } else {
                summaryBySessionID[record.sessionID] = (
                    date: record.performedAt,
                    topWeightInStoredPounds: weight
                )
            }
        }

        return summaryBySessionID.map { sessionID, summary in
            LiftProgressPoint(
                sessionID: sessionID,
                date: summary.date,
                topWeight: unit.displayValue(fromStoredPounds: summary.topWeightInStoredPounds)
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var selectedProgressPoints: [LiftProgressPoint] {
        cachedProgressPointsByExerciseName[selectedExerciseName] ?? []
    }

    private func trendSummary(for progressPoints: [LiftProgressPoint]) -> String? {
        guard let firstPoint = progressPoints.first else { return nil }
        let latestPoint = progressPoints.last ?? firstPoint
        let latestWeight = WeightFormatter.displayString(displayValue: latestPoint.topWeight, unit: weightUnit)

        if progressPoints.count < 2 {
            return "Latest top set: \(latestWeight) \(weightUnit.symbol) on \(latestPoint.date.formatted(date: .abbreviated, time: .omitted))."
        }

        let change = latestPoint.topWeight - firstPoint.topWeight
        let changePrefix = change >= 0 ? "+" : "-"
        let absoluteChange = WeightFormatter.displayString(displayValue: abs(change), unit: weightUnit)

        return "Change since first logged workout: \(changePrefix)\(absoluteChange) \(weightUnit.symbol) (\(firstPoint.date.formatted(date: .abbreviated, time: .omitted)) -> \(latestPoint.date.formatted(date: .abbreviated, time: .omitted)))."
    }

    private var progressSection: some View {
        let exercises = trackedExercises
        let points = selectedProgressPoints
        let summary = trendSummary(for: points)

        return Section("Progress Over Time") {
            VStack(alignment: .leading, spacing: 12) {
                if exercises.isEmpty {
                    Text("Log sets with weight to see progress over time.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Picker("Exercise", selection: selectedExerciseBinding(options: exercises)) {
                        ForEach(exercises, id: \.self) { exerciseName in
                            Text(exerciseName).tag(exerciseName)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.textPrimary)

                    if points.isEmpty {
                        Text("No weighted sets for this exercise yet.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Chart(points) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight (\(weightUnit.symbol))", point.topWeight)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.35), AppColors.accent.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight (\(weightUnit.symbol))", point.topWeight)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(AppColors.accent)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight (\(weightUnit.symbol))", point.topWeight)
                            )
                            .foregroundStyle(AppColors.accentAlt)
                        }
                        .frame(height: Constants.chartHeight)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: Constants.chartDesiredTickCount))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxisLabel(position: .bottom) {
                            Text("Date")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .chartYAxisLabel(position: .leading) {
                            Text("Top Weight (\(weightUnit.symbol))")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        if let summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }
            .padding(14)
            .appSurface(cornerRadius: 16, shadow: false)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
        }
    }

    private func setSummary(_ set: ExerciseSet) -> String {
        let weightText: String
        if let weight = set.weight {
            weightText = "\(WeightFormatter.displayString(weight, unit: weightUnit)) \(weightUnit.symbol)"
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

    private func rebuildHistoryCaches() {
        let history = store.workoutHistory
        cachedWorkoutDays = Set(history.map { calendar.startOfDay(for: $0.performedAt) })
        updateFilteredSessions(using: history)
    }

    private func updateFilteredSessions(using history: [WorkoutSession]? = nil) {
        let sessions = history ?? store.workoutHistory
        guard let selectedCalendarDay else {
            cachedFilteredSessions = sessions
            return
        }

        cachedFilteredSessions = sessions.filter {
            calendar.isDate($0.performedAt, inSameDayAs: selectedCalendarDay)
        }
    }

    private func rebuildProgressPointsCache() {
        let exercises = trackedExercises
        let unit = weightUnit
        var refreshed: [String: [LiftProgressPoint]] = [:]
        refreshed.reserveCapacity(exercises.count)

        for exerciseName in exercises {
            refreshed[exerciseName] = progressPoints(for: exerciseName, unit: unit)
        }

        cachedProgressPointsByExerciseName = refreshed
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
