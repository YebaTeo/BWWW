import RealityKit
import SwiftUI

/// An optional overview; its scene never writes eleven-phase journey progress.
struct Ngahuma3DView: View {
    @State private var scene = NgahumaScene()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loadAttempt = 0

    var body: some View {
        ZStack {
            Ngahuma3DSurface(scene: scene).ignoresSafeArea()
                .accessibilityHidden(true)
            if scene.loadingAssets { ProgressView("Memuat lingkungan…").padding().background(.regularMaterial) }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Ngahuma 3D").font(.headline)
                    Text("Geser untuk melihat · ketuk petak").font(.caption)
                }
                Spacer()
                Button { scene.muted.toggle() } label: {
                    Image(systemName: scene.muted ? "speaker.slash" : "speaker.wave.2")
                }.accessibilityLabel(scene.muted ? "Aktifkan suara" : "Matikan suara")
                Button("Tutup") { dismiss() }.accessibilityIdentifier("ngahuma.close")
            }.padding().background(.regularMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(scene.title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
                    if let error = scene.assetError {
                        Text(error)
                        Button("Coba lagi") { loadAttempt += 1 }
                    } else {
                        Text(scene.instruction).font(.subheadline)
                        if scene.stage == .clearing || scene.stage == .planting {
                            Button("Petak berikutnya (\(scene.count)/9)") { scene.interactWithNextPlot() }
                                .accessibilityIdentifier("ngahuma.nextPlot")
                                .accessibilityHint("Alternatif untuk mengetuk petak pada lingkungan 3D")
                        }
                        if scene.stage == .prepared {
                            Button("Amati perubahan lahan") { scene.ignite() }
                                .accessibilityIdentifier("ngahuma.ignite")
                        }
                        if scene.stage == .burning {
                            ProgressView(value: scene.progress)
                            Button("Akhiri animasi") { scene.finishBurn() }
                                .accessibilityIdentifier("ngahuma.finishBurn")
                        }
                    }
                    HStack {
                        Text("Simulasi ringkas · bukan urutan lengkap atau panduan praktik adat").font(.caption)
                        Spacer()
                        Button("Ulangi") { scene.reset() }.disabled(scene.loadingAssets || scene.assetError != nil)
                            .accessibilityIdentifier("ngahuma.replay")
                    }
                }.padding()
            }.frame(maxHeight: 260).background(.regularMaterial)
        }
        .task(id: loadAttempt) {
            scene.reduceMotion = reduceMotion
            await scene.prepareAssets()
            if !Task.isCancelled { await scene.loadAudio() }
        }
        .onChange(of: reduceMotion) { _, value in scene.reduceMotion = value }
        .onChange(of: phase) { _, value in scene.setSuspended(value != .active) }
        .onDisappear { scene.stop() }
        .preferredColorScheme(.dark)
    }
}

private struct Ngahuma3DSurface: UIViewRepresentable {
    let scene: NgahumaScene
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.attach(view)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {}
    func makeCoordinator() -> NgahumaScene { scene }
    static func dismantleUIView(_ view: ARView, coordinator: NgahumaScene) {
        coordinator.stop()
    }
}
