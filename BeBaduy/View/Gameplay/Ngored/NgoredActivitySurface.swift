import SwiftUI
struct NgoredActivitySurface: View {
    let model: NgoredViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var toolCenter: CGPoint?
    @State private var dragOrigin: CGPoint?
    @State private var strokeTracker = KoredStrokeTracker()
    private func spot(_ index: Int, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (0.17 + CGFloat(index % 4) * 0.22),
                y: size.height * (index < 4 ? 0.57 : 0.72))
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<8) { index in
                    let cut = model.removed.contains(index)
                    let hits = model.strokes[index] ?? 0
                    VStack(spacing: 0) {
                        NgoredWeedArtwork(cut: cut, hits: hits)
                        if !cut {
                            Text("\(hits)/3").font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.black.opacity(0.65), in: Capsule())
                        }
                    }.frame(width: 80, height: 95)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Gulma \(index + 1)")
                        .accessibilityValue(cut ? "Bersih" : "\(hits) dari 3 sapuan")
                        .accessibilityIdentifier("field.weed.\(index)")
                        .accessibilityAction(named: "Sapukan kored") { model.remove(index) }
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: hits)
                        .position(spot(index, geometry.size))
                }
                if model.step == .weeding {
                    Button { model.remove(8) } label: {
                        Label("Padi · pertahankan", systemImage: "leaf")
                            .font(.subheadline.weight(.semibold)).padding(12)
                            .foregroundStyle(.white).background(.black.opacity(0.7), in: Capsule())
                    }.accessibilityIdentifier("field.rice")
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.43)
                    VStack(spacing: 6) {
                        Text("Pegang dan geser kored").font(.headline)
                        Text("Tiga sapuan ke bawah per gulma · \(model.removed.count)/8 bersih").font(.subheadline)
                        if model.session.feedback.hasPrefix("Ini padi") {
                            Text(model.session.feedback).font(.subheadline.bold())
                                .accessibilityIdentifier("ngored.rice.feedback")
                        }
                    }.multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if model.step == .rain {
                    TimelineView(.animation(minimumInterval: 0.05, paused: card.mode == .help || reduceMotion || scenePhase != .active || !model.session.isActive)) { timeline in
                        Canvas { context, size in
                            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                            for i in 0..<80 {
                                let x = CGFloat((i * 73) % 313) / 313 * size.width
                                let y = CGFloat((Double(i * 19) + time * 180).truncatingRemainder(dividingBy: size.height + 20))
                                var path = Path(); path.move(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x - 4, y: y + 18))
                                context.stroke(path, with: .color(.white.opacity(0.65)), lineWidth: 1)
                            }
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
                if model.step == .weeding {
                    let initial = spot(0, geometry.size)
                    let center = toolCenter ?? CGPoint(x: initial.x + 10, y: initial.y - 18)
                    ZStack {
                        KoredTool().frame(width: 62, height: 118).allowsHitTesting(false)
                        KoredDragHandle(move: { translation in
                            guard model.session.isActive, !model.isDemonstrating else { return }
                            if dragOrigin == nil {
                                dragOrigin = center; strokeTracker.reset()
                                _ = strokeTracker.move(blade: CGPoint(x: center.x - 10, y: center.y + 48), targets: [], removed: [])
                            }
                            guard let origin = dragOrigin else { return }
                            let next = CGPoint(x: min(geometry.size.width - 30, max(30, origin.x + translation.width)),
                                               y: min(geometry.size.height - 145, max(90, origin.y + translation.height)))
                            toolCenter = next
                            let targets = (0..<8).map { index in
                                let p = spot(index, geometry.size)
                                return CGPoint(x: p.x, y: p.y + 30)
                            }
                            if let hit = strokeTracker.move(blade: CGPoint(x: next.x - 10, y: next.y + 48), targets: targets, removed: model.removed) {
                                model.remove(hit)
                            }
                        }, end: { dragOrigin = nil; strokeTracker.reset() })
                    }.frame(width: 82, height: 138)
                        .position(center)
                }
            }.contentShape(Rectangle()).coordinateSpace(name: "ngored.field").disabled(model.isDemonstrating)

        }
        .onChange(of: card.mode) { _, mode in
            if mode != .hidden { dragOrigin = nil; strokeTracker.reset() }
        }
        .onChange(of: model.step) { _, step in
            if step == .rain { card.dismiss() }
        }
        .task(id: model.removed) {
            if model.removed.isEmpty && model.strokes.isEmpty { toolCenter = nil; dragOrigin = nil; strokeTracker.reset() }
            if model.step == .cleared {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                card.showInstruction()
            }
        }
    }
}
