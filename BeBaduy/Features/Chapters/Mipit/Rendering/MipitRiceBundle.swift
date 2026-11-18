import SwiftUI

struct MipitRiceBundle: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ForEach(0..<5) { index in
                    MipitPlantArtwork(showsLeaves: false)
                        .rotationEffect(.degrees(180 + Double(index - 2) * 8))
                        .offset(x: CGFloat(index - 2) * geometry.size.width * 0.09)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.48, green: 0.32, blue: 0.14))
                    .frame(width: geometry.size.width * 0.30, height: max(3, geometry.size.height * 0.045))
                    .offset(y: geometry.size.height * 0.18)
            }
        }.accessibilityHidden(true)
    }
}
