import SwiftUI

struct NgaseukSeedPeekView: View {
    let model: NgaseukViewModel
    let target: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var falling = false
    private var filled: Bool { model.seeds.contains(target) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("HumaTerrainTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.25))
                Ellipse()
                    .fill(RadialGradient(colors: [Color.black, Color(red: 0.10, green: 0.05, blue: 0.02), Color(red: 0.36, green: 0.22, blue: 0.12)], center: .center, startRadius: 8, endRadius: geometry.size.width * 0.42))
                    .overlay(Ellipse().stroke(Color(red: 0.48, green: 0.31, blue: 0.17), lineWidth: 8))
                    .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 4)
                    .frame(width: geometry.size.width * 0.78, height: geometry.size.height * 0.22)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                if filled || model.isPouring {
                    ForEach(0..<6) { index in
                        Capsule()
                            .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.85, blue: 0.61), Color(red: 0.61, green: 0.43, blue: 0.19)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 7, height: 17).rotationEffect(.degrees(Double(index * 37)))
                            .position(x: geometry.size.width / 2 + CGFloat(index % 3 - 1) * 19,
                                      y: (filled || falling || reduceMotion ? geometry.size.height * 0.47 : geometry.size.height * 0.24) + CGFloat(index / 3) * 12)
                            .animation(reduceMotion ? nil : .easeIn(duration: 0.45).delay(Double(index) * 0.045), value: falling)
                    }.accessibilityHidden(true)
                }
                VStack(spacing: 12) {
                    Text("Lubang \(target + 1)").font(.title2.bold())
                    Text(filled ? "Benih sudah masuk" : "Gerakkan ponsel perlahan bolak-balik untuk menuang benih")
                        .font(.headline).multilineTextAlignment(.center)
                    if !filled && !model.motionActive && !model.isPouring {
                        Text("Kamu juga bisa menggunakan tombol di bawah.").font(.subheadline)
                    }
                }.foregroundStyle(.white).padding(20)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                VStack(spacing: 8) {
                    if !filled {
                        LessonButton(title: model.isPouring ? "Menuang benih…" : "Tuang benih", identifier: "ngaseuk.peek.pour", action: model.pourSeeds)
                            .disabled(model.isPouring)
                    }
                    Button(filled ? "Pilih lubang berikutnya" : "Kembali ke lahan", action: model.closePeek)
                        .font(.headline).padding(12).frame(minHeight: 48)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: Capsule())
                        .accessibilityIdentifier("ngaseuk.peek.back")
                }.padding(.horizontal, 28)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.67)
            }
        }
        .task(id: model.isPouring) {
            falling = false
            if model.isPouring {
                do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
                falling = true
            }
        }
    }
}
