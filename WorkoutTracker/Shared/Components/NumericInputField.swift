import SwiftUI

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
