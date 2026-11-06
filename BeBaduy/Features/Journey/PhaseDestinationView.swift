import SwiftUI
struct PhaseDestinationView: View {
    let phase: PhaseID
    let journey: JourneyViewModel
    let motion: MotionService
    let advance: () -> Void
    var body: some View {
        Group {
            switch phase {
            case .nukuh: NukuhView(journey: journey, motion: motion, advance: advance)
            case .ngaseuk: NgaseukView(journey: journey, motion: motion, advance: advance)
            case .ngored: NgoredView(journey: journey, advance: advance)
            case .dibuat: DibuatView(journey: journey, motion: motion, advance: advance)
            case .ngaleuitkeunPare: NgaleuitkeunPareView(journey: journey, advance: advance)
            }
        }.id(phase)
    }
}
