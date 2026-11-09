import SceneKit
import SwiftUI

struct NukuhActivitySurface: View {
    let model: NukuhViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                NukuhSurface(scene: model.scene)
                    .ignoresSafeArea()
                    .accessibilityLabel("Lahan Nukuh tiga dimensi")

                // HomeView-matched atmospheric sunlight glow, floating golden dust motes,
                // warm earth depth gradient, and radial vignette (from CinematicAtmosphereView)
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.14),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.20),
                    startRadius: 8,
                    endRadius: size.width * 0.78
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || model.scene.suspended || scenePhase != .active)) { timeline in
                    Canvas { context, canvasSize in
                        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        for i in 0..<28 {
                            let seed = Double(i)
                            let speed = 0.04 + (seed.truncatingRemainder(dividingBy: 5)) * 0.012
                            let cycle = (time * speed + seed * 0.15).truncatingRemainder(dividingBy: 1.0)
                            let y = canvasSize.height * CGFloat(1 - cycle)
                            let x = canvasSize.width * CGFloat((seed * 17).truncatingRemainder(dividingBy: 100) / 100) + sin(time * 0.8 + seed * 2) * 18
                            let radius = 1.2 + CGFloat(i % 3) * 0.8
                            let opacity = sin(cycle * .pi) * 0.65
                            context.opacity = opacity
                            context.fill(
                                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                with: .color(Color(red: 1, green: 0.90, blue: 0.65))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.42),
                        .init(color: Color(red: 0.12, green: 0.08, blue: 0.05).opacity(0.32), location: 0.65),
                        .init(color: Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.65), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.25)],
                    center: .center,
                    startRadius: size.width * 0.5,
                    endRadius: size.height * 0.85
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .task {
                model.configureLookMotion(reduceMotion: reduceMotion)
                model.scene.muted = !ActivityAudio.shared.enabled
                await model.scene.prepareAssets()
                await model.scene.loadAudio()
            }
            .onChange(of: ActivityAudio.shared.enabled) { _, enabled in
                model.scene.muted = !enabled
            }
            .onChange(of: reduceMotion) { _, value in
                model.configureLookMotion(reduceMotion: value)
            }
            .onChange(of: model.scene.stage) { _, stage in
                if stage == .prepared {
                    sheet.expand()
                }
            }
    }
}

private struct NukuhSurface: UIViewRepresentable {
    let scene: NgahumaScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        scene.attach(view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    func makeCoordinator() -> NgahumaScene { scene }

    static func dismantleUIView(_ view: SCNView, coordinator: NgahumaScene) {
        coordinator.stop()
    }
}
