import SwiftUI

/// Separate stalks let harvesting visibly change the field.
struct MipitPlantArtwork: View {
    var showsLeaves = true
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            for stalk in 0..<3 {
                let shift = CGFloat(stalk - 1) * 0.17
                let base = CGPoint(x: w * 0.5, y: h * 0.98)
                let tip = CGPoint(x: w * (0.57 + shift), y: h * (0.08 + CGFloat(stalk) * 0.055))
                var stem = Path()
                stem.move(to: base)
                stem.addQuadCurve(to: tip, control: CGPoint(x: w * (0.4 + shift), y: h * 0.42))
                context.stroke(stem, with: .color(Color(red: 0.43, green: 0.57, blue: 0.18)), lineWidth: max(2, w * 0.025))
                for leaf in 0..<(showsLeaves ? 3 : 0) {
                    let y = h * (0.64 + CGFloat(leaf) * 0.12)
                    let direction: CGFloat = (leaf + stalk) % 2 == 0 ? 1 : -1
                    let origin = CGPoint(x: w * (0.5 + shift * 0.4), y: y + h * 0.12)
                    let end = CGPoint(x: origin.x + direction * w * 0.43, y: y - h * 0.13)
                    var blade = Path()
                    blade.move(to: origin)
                    blade.addQuadCurve(to: end, control: CGPoint(x: end.x, y: origin.y - h * 0.17))
                    blade.addQuadCurve(to: origin, control: CGPoint(x: origin.x + direction * w * 0.13, y: y + h * 0.04))
                    context.fill(blade, with: .linearGradient(Gradient(colors: [
                        Color(red: 0.22, green: 0.40, blue: 0.10),
                        Color(red: 0.56, green: 0.68, blue: 0.24)
                    ]), startPoint: origin, endPoint: end))
                }
                for grain in 0..<12 {
                    let t = CGFloat(grain) / 11
                    let x = tip.x - w * 0.17 * t
                    let y = tip.y + h * 0.34 * t
                    let side: CGFloat = grain % 2 == 0 ? -1 : 1
                    let rect = CGRect(x: x + side * w * 0.035, y: y, width: w * 0.043, height: h * 0.045)
                    context.fill(Path(ellipseIn: rect), with: .linearGradient(
                        Gradient(colors: [Color(red: 1, green: 0.86, blue: 0.37), Color(red: 0.72, green: 0.43, blue: 0.12)]),
                        startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                }
            }
        }.accessibilityHidden(true)
    }
}
