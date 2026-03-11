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
                            title: "Preset Packs",
                            systemImage: "shippingbox.fill",
                            subtitle: "Start with a ready-made training style and refine it later.",
                            trailing: "\(presetPacks.count)",
                            tone: .plans
                        )

                        ForEach(presetPacks) { pack in
                            Button {
                                beginPresetOnboarding(pack)
                            } label: {
                                OnboardingPresetCard(pack: pack)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.preset.\(pack.rawValue)")
                        }
                    }

                    FlowAccentCard(tone: .today) {
                        VStack(alignment: .leading, spacing: 14) {
                            AppSectionHeader(
                                title: "Start Blank",
                                systemImage: "square.and.pencil",
                                subtitle:
                                    "Prefer to build your own structure? Start empty and add plans, templates, and exercises as you go.",
                                tone: .today
                            )

                            HStack(spacing: 8) {
                                AppStatePill(title: "No Presets", systemImage: "square.grid.3x3.slash", tone: .today)
                                AppStatePill(title: "Manual Setup", systemImage: "slider.horizontal.3", tone: .plans)
                            }

                            Button {
                                appStore.completeOnboarding(with: nil)
                            } label: {
                                Label("Start Blank", systemImage: "arrow.right.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 16))
                            .tint(AppToneStyle.today.accent)
                            .controlSize(.large)
                            .accessibilityIdentifier("onboarding.startBlank")
                        }
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
                        .appFeatureSurface()

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
                                        Label("Create Custom Exercise", systemImage: "plus.circle")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.roundedRectangle(radius: 16))
                                    .tint(AppToneStyle.plans.accent)
                                    .disabled(customExerciseName.nonEmptyTrimmed == nil)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
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
                                AppEmptyStateCard(
                                    systemImage: "magnifyingglass",
                                    title: "No matches found",
                                    message: onCreateCustom == nil
                                        ? "Try a broader search term or browse the full catalog."
                                        : "Try a broader search term, or create a custom exercise below.",
                                    tone: .warning
                                )
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(visibleCatalog) { item in
                                        Button {
                                            onPick(item)
                                            dismiss()
                                        } label: {
                                            ExercisePickerResultCard(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel(item.name)
                                        .accessibilityIdentifier("exercisePicker.item.\(item.name)")
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
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.chrome.opacity(0.94),
                                    tone.softFill.opacity(0.92),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.18)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(tone.softBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 10)
    }
}

private struct OnboardingPresetCard: View {
    let pack: PresetPack

    var body: some View {
        FlowAccentCard(tone: pack.onboardingTone) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(
                            title: pack.onboardingLabel,
                            systemImage: pack.systemImage,
                            tone: pack.onboardingTone
                        )

                        Text(pack.displayName)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(pack.description)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(pack.onboardingTone.accent)
                }

                HStack(spacing: 8) {
                    ForEach(pack.onboardingHighlights, id: \.self) { highlight in
                        Text(highlight)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(pack.onboardingTone.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .appInsetCard(
                                cornerRadius: 999,
                                fill: pack.onboardingTone.softFill.opacity(0.82),
                                border: pack.onboardingTone.softBorder
                            )
                    }
                }

                Text("Install pack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .appInputField()
    }
}

private struct ExercisePickerResultCard: View {
    let item: ExerciseCatalogItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.category.pickerSystemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.category.pickerTone.accent)
                .frame(width: 42, height: 42)
                .appInsetCard(
                    cornerRadius: 14,
                    fill: item.category.pickerTone.softFill.opacity(0.78),
                    border: item.category.pickerTone.softBorder
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    AppStatePill(
                        title: item.category.pickerLabel,
                        systemImage: item.category.pickerSystemImage,
                        tone: item.category.pickerTone
                    )

                    if let aliasPreview = item.aliasPreview {
                        Text(aliasPreview)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppToneStyle.today.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurfaceCard(
            padding: AppCardMetrics.featurePadding,
            cornerRadius: AppCardMetrics.panelCornerRadius
        )
    }
}

private extension PresetPack {
    var onboardingTone: AppToneStyle {
        switch self {
        case .generalGym:
            .today
        case .startingStrength:
            .warning
        case .fiveThreeOne:
            .progress
        case .boringButBig:
            .success
        }
    }

    var onboardingLabel: String {
        switch self {
        case .generalGym:
            "Most Flexible"
        case .startingStrength:
            "Simple Strength"
        case .fiveThreeOne:
            "Cycle Based"
        case .boringButBig:
            "Volume Focus"
        }
    }

    var onboardingHighlights: [String] {
        switch self {
        case .generalGym:
            ["Upper/Lower", "Balanced", "Flexible"]
        case .startingStrength:
            ["A/B Days", "Barbell", "Linear"]
        case .fiveThreeOne:
            ["4 Main Lifts", "Wave", "Cycles"]
        case .boringButBig:
            ["5/3/1", "5x10", "Supplemental"]
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
