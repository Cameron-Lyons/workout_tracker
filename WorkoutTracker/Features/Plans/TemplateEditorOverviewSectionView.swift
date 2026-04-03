import SwiftUI

struct TemplateEditorOverviewSectionView: View {
    @Binding var templateName: String
    @Binding var templateNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Overview",
                systemImage: "square.and.pencil",
                subtitle: "Name the template and leave a note for the next time you run it.",
                tone: .plans
            )

            TextField("Template name", text: $templateName)
                .accessibilityIdentifier("plans.editor.templateNameField")
                .textInputAutocapitalization(.words)
                .foregroundStyle(AppColors.textPrimary)
                .appInputField()

            TextField("Notes", text: $templateNote, axis: .vertical)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2...4)
                .appInputField()
        }
        .appSectionFrame(tone: .plans)
    }
}
