import SwiftUI

struct LandscapeView: View {
    let state: LandscapeState
    var label: String = "Ilustrasi huma"
    var body: some View {
        Image(state.assetName).resizable().scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityLabel(label)
    }
}
