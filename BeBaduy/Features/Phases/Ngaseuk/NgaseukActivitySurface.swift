import SwiftUI

struct NgaseukActivitySurface: View {
    let model: NgaseukViewModel
    @Environment(ActivitySheetState.self) private var sheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleHoles: Set<Int> = []
    @State private var workingTarget: Int?
    @State private var toolDepth: CGFloat = -70
    @State private var isStroking = false

    private func target(_ index: Int, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * CGFloat(index + 1) / 4,
                y: size.height * (index == 1 ? 0.66 : 0.61))
    }

    var body: some View {
        GeometryReader { geometry in
            let toolTarget = workingTarget ?? model.selectedTarget
            let point = target(toolTarget, in: geometry.size)
            let toolHeight = geometry.size.height * 0.38
            ZStack {
                ActivityPhoto(asset: "ngaseuk_before")
                if model.step != .instructions {
                    ForEach(0..<3) { index in
                        Button {
                            guard !isStroking else { return }
                            if model.step == .digging { model.dig(index) }
                            else if model.step == .seeding { model.peek(index) }
                        } label: {
                            NgaseukSoilMark(dug: visibleHoles.contains(index), seeded: model.seeds.contains(index), focused: model.step == .digging && toolTarget == index)
                        }.buttonStyle(.plain).disabled(isStroking)
                            .accessibilityLabel("Lubang \(index + 1)")
                            .accessibilityValue(model.seeds.contains(index) ? "Berisi benih" : (model.holes.contains(index) ? "Sudah dibuat" : "Belum dibuat"))
                            .accessibilityIdentifier("field.hole.\(index)")
                            .dropDestination(for: String.self) { items, _ in
                                guard !model.isDemonstrating, items.contains("rice-seed") else { return false }
                                return model.seed(index)
                            }
                            .position(target(index, in: geometry.size))
                    }
                }
                if model.step == .digging || isStroking {
                    AseukTool().frame(width: 31, height: toolHeight)
                        .position(x: point.x, y: point.y - toolHeight / 2 + toolDepth)
                        // The part below the soil surface disappears into the hole.
                        .mask(alignment: .top) { Rectangle().frame(height: point.y + 2) }
                        .allowsHitTesting(false)
                }
                if model.step == .digging {
                    VStack(spacing: 6) {
                        Text("Ketuk tanah untuk menancapkan aseuk").font(.headline)
                        Text("\(visibleHoles.count) / 3 lubang").font(.subheadline.monospacedDigit())
                    }.multilineTextAlignment(.center).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24).frame(maxHeight: .infinity, alignment: .top).padding(.top, 65)
                        .allowsHitTesting(false)
                }
                if model.step == .seeding {
                    Label("Benih", systemImage: "leaf.fill").font(.headline).padding(16)
                        .foregroundStyle(.white).background(.black.opacity(0.75), in: Capsule())
                        .draggable("rice-seed").accessibilityIdentifier("field.seed")
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.32)
                }
                if let target = model.peekTarget {
                    NgaseukSeedPeekView(model: model, target: target)
                        .transition(.opacity)
                }
            }.disabled(model.isDemonstrating)
        }
        .onChange(of: model.step) { _, step in
            switch step {
            case .digging, .seeding:
                if sheet.largeText { sheet.expand() } else { sheet.collapse() }
            case .instructions: sheet.expand()
            case .holesReady: break // Reveal planting instructions after the last stick withdraws.
            }
        }
        .onChange(of: model.peekTarget) { _, target in
            if target != nil { sheet.collapse() }
        }
        .task(id: model.holes) { await showStroke() }
    }

    @MainActor private func showStroke() async {
        let added = model.holes.subtracting(visibleHoles)
        guard let index = added.contains(model.lastDug) ? model.lastDug : added.first else {
            visibleHoles = model.holes
            if model.holes.isEmpty { workingTarget = nil; isStroking = false; toolDepth = -70 }
            return
        }
        visibleHoles = model.holes.subtracting([index])
        workingTarget = index
        isStroking = true
        toolDepth = -70
        if !reduceMotion {
            withAnimation(.easeIn(duration: 0.2)) { toolDepth = 12 }
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
        }
        visibleHoles = model.holes
        if !reduceMotion {
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            withAnimation(.easeOut(duration: 0.28)) { toolDepth = -70 }
            do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
        }
        isStroking = false
        workingTarget = nil
        toolDepth = -70
        if model.step == .holesReady { sheet.expand() }
    }
}
