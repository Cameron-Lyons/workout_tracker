import SwiftUI

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
                                        LazyVStack(spacing: 0) {
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
