import SwiftUI

struct ActivityChoice: View {
    let title: String
    var symbol = "hand.tap"
    var done = false
    var identifier = ""
    let action: () -> Void
    private var label: some View {
        Label(title, systemImage: done ? "checkmark.circle.fill" : symbol)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 4)
    }
    var body: some View {
        Group {
            if done {
                label.foregroundStyle(Color.primary).padding(.horizontal, 8)
                    .accessibilityElement(children: .combine)
            } else {
                Button(action: action) {
                    label.padding(.horizontal, 12)
                        .foregroundStyle(Color.primary)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
            }
        }
        .accessibilityValue(done ? "Selesai" : "Belum dipilih")
        .accessibilityIdentifier(identifier)
    }
}
