import SwiftUI

struct NgaleuitkeunPareActivitySurface: View {
    let model: NgaleuitkeunPareViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var drag: CGSize = .zero
    @State private var climbProgress = 0.0
    @State private var entering = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let door = CGPoint(x: size.width * 0.5, y: size.height * 0.53)
            let height = min(160, size.height * 0.22)
            let ground = CGPoint(x: size.width * 0.28, y: size.height * 0.78)
            let ladderCenter = CGPoint(x: door.x, y: door.y + height / 2)
            ZStack {
                ActivityPhoto(asset: entering ? "ngaleuitkeun_pare_after" : "ngaleuitkeun_pare_before")
                if !entering {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.16, green: 0.10, blue: 0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(AppTheme.heading.opacity(model.isLadderPlaced ? 0 : 0.85), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                        .frame(width: 44, height: 56)
                        .position(x: door.x, y: door.y - 20)
                        .accessibilityHidden(true)

                    if model.isLadderPlaced {
                        ladder(height: height, placed: true)
                            .position(ladderCenter)
                            .accessibilityHidden(true)
                        MipitRiceBundle()
                            .frame(width: 39, height: 54)
                            .scaleEffect(1 - 0.48 * climbProgress)
                            .position(x: door.x, y: door.y + height - 27 - (height - 7) * climbProgress)
                            .opacity(climbProgress < 0.85 ? 1 : max(0, (1 - climbProgress) / 0.15))
                            .allowsHitTesting(false)
                    } else {
                        ladder(height: height, placed: false)
                            .rotationEffect(.degrees(drag == .zero ? 68 : 0))
                            .padding(12)
                            .contentShape(Rectangle())
                            .position(x: ground.x + drag.width, y: ground.y + drag.height)
                            .gesture(DragGesture(coordinateSpace: .named("leuit.field"))
                                .updating($drag) { value, state, _ in state = value.translation }
                                .onEnded { value in
                                    let center = CGPoint(x: ground.x + value.translation.width, y: ground.y + value.translation.height)
                                    let top = CGPoint(x: center.x, y: center.y - height / 2)
                                    let target = CGRect(x: door.x - 44, y: door.y - 62, width: 88, height: 90)
                                    if target.contains(value.location) || target.contains(top) || target.contains(center) {
                                        model.placeLadder()
                                    }
                                })
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Tangga bambu")
                            .accessibilityHint("Seret tangga ke pintu leuit.")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { model.placeLadder() }
                            .accessibilityIdentifier("field.ladder")
                    }
                }
                if !model.isLadderPlaced {
                    Text("Seret tangga bambu ke pintu leuit.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 76)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "leuit.field")
        }
        .onChange(of: model.isLadderPlaced) { _, placed in
            if placed { card.dismiss() }
        }
        .task(id: model.isLadderPlaced && scenePhase == .active) {
            guard model.isLadderPlaced, scenePhase == .active, model.session.isActive else { return }
            climbProgress = 0
            entering = false
            do {
                if !reduceMotion {
                    for rung in 1...6 {
                        withAnimation(.easeInOut(duration: 0.24)) { climbProgress = Double(rung) / 6 }
                        try await Task.sleep(for: .milliseconds(250))
                    }
                }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { entering = true }
                try await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                model.finish()
            } catch { return }
        }
    }

    private func ladder(height: CGFloat, placed: Bool) -> some View {
        TarajeBambooView(isLeaning: placed, isHighlighted: !placed)
            .scaleEffect(height / 160)
            .frame(width: 52, height: height)
    }
}

struct TarajeBambooView: View {
    var isLeaning: Bool
    var isHighlighted: Bool = false

    var body: some View {
        ZStack {
            // Bamboo upright rails (left and right)
            HStack(spacing: 34) {
                bambooPole
                bambooPole
            }

            // Bamboo rungs (anak taraje)
            VStack(spacing: 22) {
                ForEach(0..<5) { _ in
                    bambooRung
                }
            }
        }
        .frame(width: 52, height: 160)
        .shadow(color: .black.opacity(isLeaning ? 0.35 : 0.20), radius: isLeaning ? 8 : 4, y: 4)
        .overlay(
            Group {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.action, lineWidth: 2)
                        .blur(radius: 2)
                }
            }
        )
    }

    private var bambooPole: some View {
        RoundedRectangle(cornerRadius: 3.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.88, green: 0.76, blue: 0.44),
                        Color(red: 0.70, green: 0.56, blue: 0.28),
                        Color(red: 0.88, green: 0.76, blue: 0.44)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 7, height: 160)
            .overlay(
                // Bamboo nodes / rings
                VStack(spacing: 26) {
                    ForEach(0..<6) { _ in
                        Rectangle()
                            .fill(Color(red: 0.42, green: 0.30, blue: 0.14))
                            .frame(width: 9, height: 2)
                    }
                }
            )
    }

    private var bambooRung: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.72, blue: 0.40),
                        Color(red: 0.62, green: 0.50, blue: 0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 40, height: 5.5)
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(Color(red: 0.42, green: 0.30, blue: 0.15), lineWidth: 0.8)
            )
    }
}
