import SwiftUI
struct NgaseukActivityView: View {
    let model: NgaseukViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch model.step {
            case .instructions:
                InstructionCard(title: "Buat tempat untuk benih", message: "Pegang ponsel dengan nyaman. Gerakkan sedikit ke bawah lalu kembali tenang, atau ketuk tanah. Tidak perlu mengguncang ponsel.", identifier: "ngaseuk.instructions", action: model.proceed)
            case .digging:
                Text("\(model.holes.count) / 3 lubang").font(.headline)
                Text("Ketuk tanda pada lahan. Tarik panel ke bawah untuk melihat seluruh lahan.")
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Buat lubang \(index + 1)", done: model.holes.contains(index), identifier: "dig_\(index)") { model.dig(index) }
                }
                Button(model.motionActive ? "Gunakan sentuhan" : "Gunakan gerakan lembut") {
                    if model.motionActive { model.pauseMotion() } else { model.startMotion() }
                }.frame(minHeight: 44)
            case .holesReady:
                InstructionCard(title: "Tanah berhasil dilubangi", message: "Sekarang seret benih ke setiap lubang. Kamu juga bisa mengetuk lubang untuk mengisinya.", identifier: "ngaseuk.seeds", action: model.proceed)
            case .seeding:
                Text("Seret benih pada lahan ke lubang, atau gunakan pilihan di bawah.")
                Text("\(model.seeds.count) / 3 lubang berisi benih").font(.headline)
                ForEach(0..<3) { index in
                    ActivityChoice(title: "Isi lubang \(index + 1)", symbol: "leaf", done: model.seeds.contains(index), identifier: "seed_\(index)") { model.seed(index) }
                }
            }
        }.disabled(model.isDemonstrating)
    }
}
