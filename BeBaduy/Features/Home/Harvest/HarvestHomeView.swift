import SwiftUI

/// The four visual milestones are a preview, separate from durable learning progress.
struct HarvestHomeView: View {
    let journey: JourneyViewModel
    let isActive: Bool
    let onResume: () -> Void
    let onJourney: () -> Void
    let onExplore: () -> Void
    let onCompletion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var selectedStage = 0

    private var stage: GrowthStage { GrowthStage.currentStage(for: progress) }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                CinematicAtmosphereView(progress: progress, isActive: isActive)
                    .accessibilityHidden(true)
                RiceCropRealityView(progress: progress, isActive: isActive)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    header
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(growthGesture)
                        .accessibilityHidden(true)
                    GrowthOverlayView(
                        stage: stage,
                        journey: journey,
                        onResume: onResume,
                        onExplore: onExplore,
                        onCompletion: onCompletion,
                        onNext: { selectStage((stage.id + 1) % GrowthStage.allStages.count) }
                    )
                    .frame(maxWidth: 440)
                    .frame(maxHeight: viewport.size.height * 0.60)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedStage)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("BeBaduy")
                    .font(.headline.weight(.black))
                    .tracking(1.2)
                Spacer(minLength: 8)
                Button(action: onJourney) {
                    Label("Perjalanan", systemImage: "list.bullet")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("home.journey")
            }
            HStack(spacing: 0) {
                Text(stage.stepCounterString)
                    .font(.subheadline.monospaced().bold())
                    .accessibilityLabel("Pratinjau \(stage.id + 1) dari 4")
                Spacer(minLength: 4)
                ForEach(GrowthStage.allStages) { item in
                    Button { selectStage(item.id) } label: {
                        Circle()
                            .fill(item.id == stage.id ? HarvestPalette.gold : HarvestPalette.ivory.opacity(0.5))
                            .frame(width: item.id == stage.id ? 9 : 6, height: item.id == stage.id ? 9 : 6)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Pratinjau \(item.name)")
                    .accessibilityAddTraits(item.id == stage.id ? [.isSelected] : [])
                    .accessibilityIdentifier("home.stage.\(item.id)")
                }
            }
        }
        .foregroundStyle(HarvestPalette.gold)
        .padding(.horizontal, 14)
        .background(HarvestPalette.card.opacity(0.90), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(HarvestPalette.gold.opacity(0.3)))
    }

    private var growthGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                if dragStart == nil { dragStart = progress }
                progress = min(1, max(0, (dragStart ?? progress) - value.translation.height / 360))
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                let initialStage = GrowthStage.currentStage(for: start).id
                let displacement = -value.predictedEndTranslation.height
                let next = abs(displacement) > 60 ? initialStage + (displacement > 0 ? 1 : -1) : initialStage
                dragStart = nil
                selectStage(min(3, max(0, next)))
            }
    }

    private func selectStage(_ index: Int) {
        selectedStage = index
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            progress = GrowthStage.allStages[index].targetProgress
        }
    }
}
