import SwiftUI

/// Reusable woven-glass explanation card, sized to the approved Sketch design.
struct HumaGlassCard<Content: View>: View {
    /// Sketch's dimensions in points. A parent can propose a narrower width.
    var width: CGFloat = 330
    var height: CGFloat = 480
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let gold = Color(red: 0.96, green: 0.65, blue: 0.25)
    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    var body: some View {
        GeometryReader { geometry in
            let cardHeight = geometry.size.height
            ZStack {
                if reduceTransparency || contrast == .increased {
                    shape.fill(Color(red: 0.22, green: 0.17, blue: 0.12))
                } else {
                    shape.fill(.clear)
                        .glassEffect(.regular.tint(.brown.opacity(0.24)), in: shape)
                }
                HumaWeavePattern()
                    .foregroundStyle(gold.opacity(0.28))
                    .clipShape(shape)
                ViewThatFits(in: .vertical) {
                    cardContent
                    ScrollView { cardContent }
                        .accessibilityIdentifier("lesson.explanation.content.scroll")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, min(48, cardHeight * 0.1))
            }
            .overlay {
                shape.strokeBorder(gold.opacity(0.8), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) { corner }
            .overlay(alignment: .bottomTrailing) { corner.rotationEffect(.degrees(180)) }
        }
        .aspectRatio(width / height, contentMode: .fit)
        .frame(maxWidth: width, maxHeight: height)
        .accessibilityElement(children: .contain)
    }

    private var cardContent: some View {
        content()
            .font(.system(.title3, design: .rounded))
            .foregroundStyle(AppTheme.cream)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var corner: some View {
        HumaFoldShape()
            .fill(gold.opacity(0.12))
            .overlay {
                HumaFoldShape().stroke(gold.opacity(0.9), lineWidth: 1)
                HumaFoldShape().stroke(gold.opacity(0.65), lineWidth: 0.7)
                    .padding(4)
            }
            .frame(width: 132, height: 88)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct HumaFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 24))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 24, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.42),
                      control1: CGPoint(x: rect.width * 0.82, y: rect.height * 0.46),
                      control2: CGPoint(x: rect.width * 0.66, y: rect.height * 0.32))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                      control1: CGPoint(x: rect.width * 0.15, y: rect.height * 0.48),
                      control2: CGPoint(x: rect.width * 0.13, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct HumaWeavePattern: View {
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.foreground)
                .mask {
                    // Inverting luminance turns the white background transparent.
                    // Aspect fill preserves the supplied motif's proportions.
                    Image("HumaTenunPattern")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .colorInvert()
                        .luminanceToAlpha()
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HumaGlassCardPreview: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    HStack {
                        Spacer()
                        Button("Ulangi") {}
                            .buttonStyle(.glass)
                            .tint(AppTheme.orange)
                    }
                    HumaGlassCard() {
                        VStack(spacing: 24) {
                            Text("Kami memanfaatkan abu sisa pembakaran rumput dan daun kering untuk menyuburkan tanah.")
                            Text("Jadi, sisa tanaman yang sudah tidak digunakan masih punya manfaat, lho!")
                        }
                    }
                    Button("Lanjut ke tahap berikutnya") {}
                        .buttonStyle(.glassProminent)
                        .tint(AppTheme.orange)
                        .controlSize(.large)
                }
                .frame(maxWidth: 330)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background {
            GeometryReader { backdrop in
                Image("HumaEnvironment")
                    .resizable()
                    .scaledToFill()
                    .frame(width: backdrop.size.width, height: backdrop.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Huma glass · landscape background") {
    HumaGlassCardPreview()
}

#Preview("Huma glass · large text") {
    HumaGlassCardPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
}

