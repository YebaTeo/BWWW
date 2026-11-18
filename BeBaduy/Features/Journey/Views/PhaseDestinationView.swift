import SwiftUI
struct PhaseDestinationView: View {
    let phase: PhaseID
    let journey: JourneyViewModel
    let motion: MotionService
    let advance: () -> Void
    var body: some View {
        Group {
            switch phase {
            case .narawas: NarawasView(journey: journey, motion: motion, advance: advance)
            case .ngaseuk: NgaseukView(journey: journey, motion: motion, advance: advance)
            case .ngored: NgoredView(journey: journey, motion: motion, advance: advance)
            case .ngalantai: NgalantaiView(journey: journey, motion: motion, advance: advance)
            case .mipit: MipitView(journey: journey, motion: motion, advance: advance)
            case .ngaleuitkeunPare: NgaleuitkeunPareView(journey: journey, advance: advance)
            }
        }.id(phase)
    }
}
