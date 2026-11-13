import SwiftUI

/// A tool card that can flip between its woven and illustrated sides. The caller supplies the illustration and owns the reveal state.
struct ToolRevealCard<Artwork: View>: View {
    let title: String
    let description: String
    @Binding var isRevealed: Bool
    @ViewBuilder var artwork: () -> Artwork

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .aspectRatio(3.0 / 4, contentMode: .fit)
            .frame(maxWidth: 330)
            .overlay {
                ToolRevealFaces(
                    angle: isRevealed ? 180 : 0,
                    title: title,
                    description: description,
                    artwork: artwork
                )
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .onTapGesture { isRevealed = false }
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text("Tutup kartu alat")) { isRevealed = false }
                .accessibilityHidden(!isRevealed)
                .allowsHitTesting(isRevealed)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: isRevealed)
            }
            .overlay {
                if !isRevealed {
                    Button {
                        isRevealed = true
                    } label: {
                        Color.clear.contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Buka kartu alat")
                    .accessibilityIdentifier("lesson.equipment.reveal")
                    .accessibilityHint("Menampilkan nama, gambar, dan kegunaan alat.")
                }
            }
    }
}

private struct ToolRevealFaces<Artwork: View>: View, Animatable {
    nonisolated var angle: Double
    let title: String
    let description: String
    @ViewBuilder var artwork: () -> Artwork

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private let shape = RoundedRectangle(cornerRadius: 18)

    var body: some View {
        GeometryReader { geometry in
            let showingTool = angle >= 90

            ZStack {
                if showingTool {
                    let illustrationHeight = geometry.size.height * 0.46
                    Color(red: 0.17, green: 0.13, blue: 0.12)
                    ViewThatFits(in: .vertical) {
                        details(illustrationHeight: illustrationHeight)
                        ScrollView { details(illustrationHeight: illustrationHeight) }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                } else {
                    Image("ToolRevealWeave")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(.black.opacity(0.32))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(AppTheme.heading.opacity(0.6), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .rotation3DEffect(.degrees(showingTool ? angle - 180 : angle),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        }
    }

    private func details(illustrationHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.heading)
                .accessibilityAddTraits(.isHeader)

            artwork()
                .frame(maxWidth: .infinity)
                .frame(height: illustrationHeight)
                .accessibilityHidden(true)

            Text(description)
                .font(.body)
                .foregroundStyle(AppTheme.cream)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

private struct ToolRevealPreview<Artwork: View>: View {
    let title: String
    let description: String
    @ViewBuilder var artwork: () -> Artwork
    @State private var isRevealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Ada alat apa di balik kartu ini?\n\nKetuk untuk melihatnya!")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.cream)
                    .opacity(isRevealed ? 0 : 1)
                    .accessibilityHidden(isRevealed)

                ToolRevealCard(title: title, description: description, isRevealed: $isRevealed,
                               artwork: artwork)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
        .background {
            GeometryReader { geometry in
                Image("HumaTerrainTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(.black.opacity(0.45))
            }
            .ignoresSafeArea()
        }
    }
}

#Preview("Tool reveal · Aseuk") {
    ToolRevealPreview(title: "Aseuk", description: "Tongkat kayu yang digunakan untuk membuat lubang tanam.") {
        AseukTool().frame(width: 34)
    }
}

#Preview("Tool reveal · Kored") {
    ToolRevealPreview(title: "Kored", description: "Cangkul kecil bermata miring untuk membersihkan gulma dan menggemburkan tanah.") {
        KoredTool().frame(width: 150, height: 120)
    }
}

#Preview("Tool reveal · Etem (Mipit)") {
    ToolRevealPreview(title: "Etem", description: "Alat kecil untuk mipit (mencubit batang padi) saat panen dengan gerakan seperti memetik.") {
        Image("mipit_etem")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 160, maxHeight: 140)
    }
}
