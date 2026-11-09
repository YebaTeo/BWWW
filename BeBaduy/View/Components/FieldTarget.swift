import SwiftUI

struct FieldTarget: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 18, weight: .semibold))
                .padding(14).frame(minWidth: 56, minHeight: 56)
                .foregroundStyle(.white)
                .background(.black.opacity(0.72), in: Capsule())
        }.buttonStyle(.plain)
    }
}
