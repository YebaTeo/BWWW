import SwiftUI
struct PhaseDestinationView: View {
    let phase: PhaseID
    let journey: JourneyViewModel
    let motion: MotionService
    let advance: () -> Void
    var body: some View {
        Group {
            switch phase {
            case .narawas: NarawasView(journey: journey, advance: advance)
            case .nyacar: NyacarView(journey: journey, advance: advance)
            case .ngaganggang: NgaganggangView(journey: journey, advance: advance)
            case .ngahuru: NgahuruView(journey: journey, advance: advance)
            case .ngaseuk: NgaseukView(journey: journey, motion: motion, advance: advance)
            case .ngored: NgoredView(journey: journey, advance: advance)
            case .ngubaranPare: NgubaranPareView(journey: journey, advance: advance)
            case .dibuat: DibuatView(journey: journey, advance: advance)
            case .dryingRice: DryingRiceView(journey: journey, advance: advance)
            case .ngunjal: NgunjalView(journey: journey, advance: advance)
            case .ngaleuitkeunPare: NgaleuitkeunPareView(journey: journey, advance: advance)
            }
        }.id(phase)
    }
}
