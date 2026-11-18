import SwiftUI

/// Full-bleed artwork; interactive targets are layered above it by each phase.
struct ActivityPhoto: View {
    let asset: String
    var body: some View {
        GeometryReader { geometry in
            Image(asset).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true)
    }
}

