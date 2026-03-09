import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    AppHeroCard(
                        eyebrow: "WorkoutTracker v2",
                        title: "Build your training workspace",
                        subtitle: "Choose a preset pack or start from a blank slate. You can add more plans later from the Plans tab.",
                        systemImage: "sparkles.rectangle.stack",
                        metrics: [
                            AppHeroMetric(
                                id: "today",
                                label: "Today",
                                value: "Quick starts",
                                systemImage: "sun.max"
                            ),
                            AppHeroMetric(
                                id: "plans",
                                label: "Plans",
                                value: "Custom templates",
                                systemImage: "list.bullet.rectangle"
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
                            )
                        ]
                    )

                    ForEach(PresetPack.allCases) { pack in
                        Button {
                            appStore.completeOnboarding(with: pack)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(pack.displayName, systemImage: pack.systemImage)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppColors.textPrimary)

                                    Spacer()

                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Text(pack.description)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appSurface(cornerRadius: 16, shadow: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.preset.\(pack.rawValue)")
                    }

                    Button {
                        appStore.completeOnboarding(with: nil)
                    } label: {
                        Label("Start Blank", systemImage: "square.and.pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding.startBlank")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let catalog: [ExerciseCatalogItem]
    let title: String
    let onPick: (ExerciseCatalogItem) -> Void
    let onCreateCustom: ((String) -> Void)?

    @State private var searchText = ""
    @State private var customExerciseName = ""

    private var filteredCatalog: [ExerciseCatalogItem] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            return catalog
        }

        return catalog.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearch)
                || $0.aliases.contains(where: { $0.localizedCaseInsensitiveContains(trimmedSearch) })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    TextField("Search exercises", text: $searchText)
                        .foregroundStyle(AppColors.textPrimary)
                        .appInputField()

                    if let onCreateCustom {
                        VStack(spacing: 10) {
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
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppColors.accent)
                            .disabled(customExerciseName.nonEmptyTrimmed == nil)
                        }
                        .padding(14)
                        .appSurface(cornerRadius: 14, shadow: false)
                    }

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredCatalog) { item in
                                Button {
                                    onPick(item)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.name)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(item.category.rawValue.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .appSurface(cornerRadius: 14, shadow: false)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(item.name)
                                .accessibilityIdentifier("exercisePicker.item.\(item.name)")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
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
