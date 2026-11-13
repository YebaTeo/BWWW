import SwiftUI

struct NgaleuitkeunPareActivityView: View {
    let model: NgaleuitkeunPareViewModel
    @Environment(ActivityCardState.self) private var card

    var body: some View {
        InstructionCard(title: "Pasang tangga bambu",
                        message: "Seret tangga ke pintu. Setelah tangga terpasang, perhatikan ikatan padi bergerak naik dan masuk ke leuit.",
                        identifier: "activity.card") {
            card.dismiss()
        }
    }
}
