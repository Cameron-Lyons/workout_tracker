import SwiftUI

struct ExercisePickerSearchIndex {
    private struct Entry {
        var item: ExerciseCatalogItem
        var normalizedSearchText: String
    }

    private let entries: [Entry]

    init(catalog: [ExerciseCatalogItem]) {
        entries = catalog.map { item in
            Entry(
                item: item,
                normalizedSearchText: ([item.name] + item.aliases)
                    .map(Self.normalize)
                    .joined(separator: "\n")
            )
        }
    }

    func filter(query: String) -> [ExerciseCatalogItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = Self.normalize(trimmedQuery)
        guard !normalizedQuery.isEmpty else {
            return entries.map(\.item)
        }

        return entries.compactMap { entry in
            entry.normalizedSearchText.contains(normalizedQuery) ? entry.item : nil
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct OnboardingView: View {
    @Environment(AppStore.self) private var appStore

    private let presetPacks = PresetPack.allCases

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 18) {
                    AppHeroCard(
                        eyebrow: "WorkoutTracker",
                        title: "Choose your starting setup",
                        subtitle: "Install a preset pack for a faster launch, or start blank and build your own system from Plans.",
                        systemImage: "sparkles.rectangle.stack",
                        metrics: [
                            AppHeroMetric(
                                id: "packs",
                                label: "Preset Packs",
                                value: "\(presetPacks.count)",
                                systemImage: "shippingbox"
                            ),
                            AppHeroMetric(
                                id: "blank",
                                label: "Blank Setup",
                                value: "Available",
                                systemImage: "square.and.pencil"
                            ),
                            AppHeroMetric(
                                id: "progress",
                                label: "Progress",
                                value: "PRs + trends",
                                systemImage: "chart.line.uptrend.xyaxis"
                            ),
                            AppHeroMetric(
                                id: "session",
                                label: "Session",
                                value: "Autosaved",
                                systemImage: "square.and.arrow.down"
                            ),
                        ],
                        tone: .plans
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(
                            title: "Choose A Path",
                            systemImage: "point.3.filled.connected.trianglepath.dotted",
                            subtitle: "Pick a preset or start blank. The structure can be edited later.",
                            trailing: "\(presetPacks.count + 1)",
                            tone: .plans
                        )

                        OnboardingOptionsPanel(
                            presetPacks: presetPacks,
                            onSelectPack: beginPresetOnboarding,
                            onStartBlank: {
                                appStore.completeOnboarding(with: nil)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func beginPresetOnboarding(_ pack: PresetPack) {
        guard appStore.settingsStore.isCompletingOnboarding == false else {
            return
        }

        appStore.settingsStore.isCompletingOnboarding = true
        appStore.settingsStore.hasCompletedOnboarding = true

        Task { @MainActor in
            await Task.yield()
            appStore.completeOnboarding(with: pack)
            appStore.settingsStore.isCompletingOnboarding = false
        }
    }
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onPick: (ExerciseCatalogItem) -> Void
    let onCreateCustom: ((String) -> Void)?

    private let searchIndex: ExercisePickerSearchIndex
    private let catalogCount: Int

    @State private var searchText = ""
    @State private var customExerciseName = ""

    @State private var visibleCatalog: [ExerciseCatalogItem]

    init(
        catalog: [ExerciseCatalogItem],
        title: String,
        onPick: @escaping (ExerciseCatalogItem) -> Void,
        onCreateCustom: ((String) -> Void)? = nil
    ) {
        self.title = title
        self.onPick = onPick
        self.onCreateCustom = onCreateCustom
        catalogCount = catalog.count
        searchIndex = ExercisePickerSearchIndex(catalog: catalog)
        _visibleCatalog = State(initialValue: catalog)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResultsSubtitle: String {
        if trimmedSearchText.isEmpty {
            return "Browse the full catalog or search by exercise name and aliases."
        }

        return "Showing matches for \"\(trimmedSearchText)\" across names and aliases."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        AppHeroCard(
                            eyebrow: "Exercise Library",
                            title: title,
                            subtitle: searchResultsSubtitle,
                            systemImage: "magnifyingglass.circle.fill",
                            metrics: [
                                AppHeroMetric(
                                    id: "results",
                                    label: "Results",
                                    value: "\(visibleCatalog.count)",
                                    systemImage: "list.bullet"
                                ),
                                AppHeroMetric(
                                    id: "catalog",
                                    label: "Catalog",
                                    value: "\(catalogCount)",
                                    systemImage: "books.vertical"
                                ),
                                AppHeroMetric(
                                    id: "custom",
                                    label: "Custom",
                                    value: onCreateCustom == nil ? "Off" : "Available",
                                    systemImage: "plus.circle"
                                ),
                                AppHeroMetric(
                                    id: "query",
                                    label: "Search",
                                    value: trimmedSearchText.isEmpty ? "Browse" : "Active",
                                    systemImage: "scope"
                                ),
                            ],
                            tone: .today
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            AppSectionHeader(
                                title: "Search",
                                systemImage: "magnifyingglass",
                                subtitle: "Look up exercises by movement name or common alias.",
                                trailing: "\(visibleCatalog.count) results",
                                tone: .today
                            )

                            SearchInputField(
                                placeholder: "Search exercises",
                                text: $searchText
                            )
                        }

                        if let onCreateCustom {
                            FlowAccentCard(tone: .plans) {
                                VStack(alignment: .leading, spacing: 14) {
                                    AppSectionHeader(
                                        title: "Create Custom Exercise",
                                        systemImage: "plus.circle.fill",
                                        subtitle:
                                            "Add a movement that is not in the library and use it immediately in this template or session.",
                                        tone: .plans
                                    )

                                    TextField("New custom exercise", text: $customExerciseName)
                                        .textInputAutocapitalization(.words)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .appInputField()

                                    Button {
                                        guard let trimmedName = customExerciseName.nonEmptyTrimmed else {
                                            return
                                        }

                                        onCreateCustom(trimmedName)
                                        dismiss()
                                    } label: {
                                        Label("Create Custom Exercise", systemImage: "plus")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .appPrimaryActionButton(tone: .plans)
                                    .disabled(customExerciseName.nonEmptyTrimmed == nil)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            FlowAccentCard(tone: .plans) {
                                VStack(alignment: .leading, spacing: 14) {
                                    AppSectionHeader(
                                        title: "Results",
                                        systemImage: "list.bullet.rectangle",
                                        subtitle: trimmedSearchText.isEmpty
                                            ? "The full exercise catalog is ready to browse."
                                            : "Matching names and aliases for your current search.",
                                        trailing: "\(visibleCatalog.count)",
                                        tone: .plans
                                    )

                                    if visibleCatalog.isEmpty {
                                        InlineResultsEmptyState(
                                            title: "No matches found",
                                            message: onCreateCustom == nil
                                                ? "Try a broader search term or browse the full catalog."
                                                : "Try a broader search term, or create a custom exercise below.",
                                            tone: .warning
                                        )
                                    } else {
                                        VStack(spacing: 0) {
                                            ForEach(Array(visibleCatalog.enumerated()), id: \.element.id) { index, item in
                                                Button {
                                                    onPick(item)
                                                    dismiss()
                                                } label: {
                                                    ExercisePickerResultRow(item: item)
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityElement(children: .combine)
                                                .accessibilityLabel(item.name)
                                                .accessibilityIdentifier("exercisePicker.item.\(item.name)")

                                                if index < visibleCatalog.count - 1 {
                                                    Rectangle()
                                                        .fill(AppColors.stroke.opacity(0.78))
                                                        .frame(height: 1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText, initial: false) { _, newValue in
                visibleCatalog = searchIndex.filter(query: newValue)
            }
        }
    }
}

private struct FlowAccentCard<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .appFeatureSurface(tone: tone)
    }
}

private struct OnboardingOptionsPanel: View {
    let presetPacks: [PresetPack]
    let onSelectPack: (PresetPack) -> Void
    let onStartBlank: () -> Void

    var body: some View {
        FlowAccentCard(tone: .plans) {
            VStack(spacing: 0) {
                ForEach(Array(presetPacks.enumerated()), id: \.element.id) { index, pack in
                    Button {
                        onSelectPack(pack)
                    } label: {
                        OnboardingPresetRow(pack: pack)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.preset.\(pack.rawValue)")

                    if index < presetPacks.count - 1 {
                        Rectangle()
                            .fill(AppColors.stroke.opacity(0.78))
                            .frame(height: 1)
                    }
                }

                Rectangle()
                    .fill(AppColors.strokeStrong.opacity(0.88))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                Button {
                    onStartBlank()
                } label: {
                    OnboardingBlankRow()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.startBlank")
            }
        }
    }
}

private struct OnboardingPresetRow: View {
    let pack: PresetPack

    var body: some View {
        let tone = pack.onboardingTone

        HStack(alignment: .top, spacing: 14) {
            Image(systemName: pack.systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tone.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: tone.softFill.opacity(0.72),
                    border: tone.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(pack.onboardingLabel.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                Text(pack.displayName)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pack.description)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pack.onboardingHighlights.map { $0.uppercased() }.joined(separator: " • "))
                    .font(.caption.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.black))
                .foregroundStyle(tone.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}

private struct OnboardingBlankRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppToneStyle.today.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: AppToneStyle.today.softFill.opacity(0.72),
                    border: AppToneStyle.today.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("BUILD YOUR OWN")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(AppToneStyle.today.accent)

                Text("Start Blank")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Begin with an empty setup and add plans, templates, and exercises as you go.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("NO PRESETS • FULL CONTROL")
                    .font(.caption.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.88))
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.black))
                .foregroundStyle(AppToneStyle.today.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}

private struct InlineResultsEmptyState: View {
    let title: String
    let message: String
    let tone: AppToneStyle

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(tone.accent)
                .frame(width: 36, height: 36)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: tone.softFill.opacity(0.72),
                    border: tone.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

private struct SearchInputField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppToneStyle.today.accent)

            TextField(placeholder, text: $text)
                .foregroundStyle(AppColors.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(8)
                        .appInsetCard(
                            cornerRadius: 6,
                            fill: AppColors.surfaceStrong.opacity(0.88),
                            border: AppColors.strokeStrong
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .appInputField()
    }
}

private struct ExercisePickerResultRow: View {
    let item: ExerciseCatalogItem

    var body: some View {
        let tone = item.category.pickerTone

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.category.pickerSystemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tone.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: tone.softFill.opacity(0.78),
                    border: tone.softBorder
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.category.pickerLabel.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                if let aliasPreview = item.aliasPreview {
                    Text(aliasPreview)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.up.forward")
                .font(.caption.weight(.black))
                .foregroundStyle(tone.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

private extension PresetPack {
    var onboardingTone: AppToneStyle {
        switch self {
        case .generalGym:
            .today
        case .phul:
            .success
        case .startingStrength:
            .warning
        case .strongLiftsFiveByFive:
            .warning
        case .greyskullLP:
            .plans
        case .fiveThreeOne:
            .progress
        case .boringButBig:
            .success
        case .madcowFiveByFive:
            .progress
        case .gzclp:
            .plans
        }
    }

    var onboardingLabel: String {
        switch self {
        case .generalGym:
            "Most Flexible"
        case .phul:
            "4-Day Split"
        case .startingStrength:
            "Simple Strength"
        case .strongLiftsFiveByFive:
            "Novice 5x5"
        case .greyskullLP:
            "AMRAP Linear"
        case .fiveThreeOne:
            "Cycle Based"
        case .boringButBig:
            "Volume Focus"
        case .madcowFiveByFive:
            "Intermediate"
        case .gzclp:
            "Tiered Progression"
        }
    }

    var onboardingHighlights: [String] {
        switch self {
        case .generalGym:
            ["Upper/Lower", "Balanced", "Flexible"]
        case .phul:
            ["Power", "Hypertrophy", "Upper/Lower"]
        case .startingStrength:
            ["A/B Days", "Barbell", "Linear"]
        case .strongLiftsFiveByFive:
            ["A/B Days", "5x5", "Barbell"]
        case .greyskullLP:
            ["A/B Days", "AMRAP", "Linear"]
        case .fiveThreeOne:
            ["4 Main Lifts", "Wave", "Cycles"]
        case .boringButBig:
            ["5/3/1", "5x10", "Supplemental"]
        case .madcowFiveByFive:
            ["3 Days", "Ramp Sets", "Weekly"]
        case .gzclp:
            ["T1/T2/T3", "4 Days", "Powerbuilding"]
        }
    }
}

private extension ExerciseCatalogItem {
    var aliasPreview: String? {
        let preview = aliases.prefix(2)
        guard !preview.isEmpty else {
            return nil
        }

        return preview.joined(separator: " • ")
    }
}

private extension ExerciseCategory {
    var pickerLabel: String {
        switch self {
        case .chest:
            "Chest"
        case .back:
            "Back"
        case .shoulders:
            "Shoulders"
        case .legs:
            "Legs"
        case .arms:
            "Arms"
        case .fullBody:
            "Full Body"
        case .conditioning:
            "Conditioning"
        case .core:
            "Core"
        case .custom:
            "Custom"
        }
    }

    var pickerSystemImage: String {
        switch self {
        case .chest:
            "figure.strengthtraining.traditional"
        case .back:
            "figure.rower"
        case .shoulders:
            "figure.arms.open"
        case .legs:
            "figure.run"
        case .arms:
            "figure.flexibility"
        case .fullBody:
            "figure.mixed.cardio"
        case .conditioning:
            "heart.circle"
        case .core:
            "figure.core.training"
        case .custom:
            "sparkles"
        }
    }

    var pickerTone: AppToneStyle {
        switch self {
        case .legs, .conditioning:
            .warning
        case .fullBody, .core:
            .progress
        case .custom:
            .plans
        case .chest, .back, .shoulders, .arms:
            .today
        }
    }
}

struct NumericInputField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .foregroundStyle(AppColors.textPrimary)
                .appInputField()
        }
    }
}
