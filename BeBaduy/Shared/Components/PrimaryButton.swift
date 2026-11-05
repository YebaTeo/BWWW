import SwiftUI

struct PrimaryButton: View {
    let title: String
    var identifier = ""
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
        }
        .buttonStyle(.borderedProminent).controlSize(.large).tint(AppTheme.leaf)
        .accessibilityIdentifier(identifier)
    }
}
struct ActivityChoice: View {
    let title: String
    var symbol = "hand.tap"
    var done = false
    var identifier = ""
    let action: () -> Void
    private var label: some View {
        Label(title, systemImage: done ? "checkmark.circle.fill" : symbol)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
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
