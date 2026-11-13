import Foundation

struct PhaseContent: Identifiable, Sendable {
    let id: PhaseID
    let title: String
    let subtitle: String
    let introduction: String
    let instruction: String
    let explanation: String
    let result: String
    let timeCue: String?
    let sourceIDs: [String]
    var before: LandscapeState { LandscapeState(phase: id, isResult: false) }
    var after: LandscapeState { LandscapeState(phase: id, isResult: true) }
    static func content(for id: PhaseID) -> PhaseContent {
        switch id {
        case .narawas:
            PhaseContent(
                id: .narawas,
                title: "Narawas",
                subtitle: "Menyiapkan lahan",
                introduction: "Kami menebang pohon di lahan yang telah dipilih secara adat untuk mulai ditanami pare huma (padi ladang).",
                instruction: "Usap \(NarawasPlot.count) pohon contoh, lalu ketuk setiap petak untuk menyalakan api virtual.",
                explanation: "Kami memanfaatkan abu sisa pembakaran rumput dan daun kering untuk menyuburkan tanah.\n\nJadi, sisa tanaman yang sudah tidak digunakan masih punya manfaat, lho!",
                result: "Lahan sudah siap!\n\nKini, huma lebih siap untuk memasuki tahap penanaman!",
                timeCue: nil,
                sourceIDs: ["S1", "S5"]
            )
        case .ngaseuk:
            PhaseContent(
                id: .ngaseuk,
                title: "Ngaseuk",
                subtitle: "Membuka tempat untuk benih",
                introduction: "Setelah lahan siap, kami melubangi tanah untuk menanam binih pare (benih padi) yang telah diberkati secara adat.",
                instruction: "Tusukkan aseuk tiga kali pada setiap titik untuk memperbesar tiga lubang, lalu masukkan benih.",
                explanation: "Proses ngaseuk dilakukan secara gotong-royong dalam keluarga.\n\nPara Bapa (bapak) Ngaseuk dan para Ambu (ibu) akan memasukkan beberapa butir binih ke dalam lubang.\n\nSeru, ya, kalau pekerjaan dilakukan bersama-sama!",
                result: "Benih sudah tertanam!\n\nSekarang, kita tinggal menunggu benih-benih ini tumbuh menjadi tanaman padi.",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .ngored:
            PhaseContent(
                id: .ngored,
                title: "Ngored",
                subtitle: "Merawat padi muda",
                introduction: "Selama pare tumbuh, kami membersihkan lahan dari rumput liar agar padi dapat tumbuh dengan baik.",
                instruction: "Gunakan kored untuk membersihkan empat gulma contoh di sekitar padi.",
                explanation: "Di Baduy, kami tidak membuat saluran irigasi karena kami percaya hal itu dapat melukai tanah.\n\nOleh karena itu, kami menanam saat musim hujan (September - November) di lahan miring. Huma yang berada di lahan miring membantu air hujan mengalir secara alami.",
                result: "Hujan telah membasahi huma. Lihatlah semua pare yang ditanam semakin bertumbuh!",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .mipit:
            PhaseContent(
                id: .mipit,
                title: "Mipit",
                subtitle: "Memanen padi",
                introduction: "Setelah dirawat hingga menguning, tibalah waktunya kami memanen pare huma.",
                instruction: "Cubit padi dengan dua jari untuk memanen.",
                explanation: "Saat mipit, kami mengumpulkan batang pare dalam satu kepalan tangan yang disebut emeul.\n\nSetiap enam emeul akan disatukan menjadi satu pocong yang beratnya 3 kg.\n\nBegitulah cara kami mengukur hasil panen!",
                result: "Akhirnya, proses panen sudah selesai!",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .ngalantai:
            PhaseContent(
                id: .ngalantai,
                title: "Ngalantai",
                subtitle: "Mengeringkan padi",
                introduction: "Kemudian, pare hasil panen dijemur di bawah sinar matahari agar kering sebelum disimpan.",
                instruction: "Putar ponsel, lalu jaga bambu tetap rata selama tiga detik.",
                explanation: "Pare huma yang sudah dipocong kemudian digantungkan di Lantaian bambu untuk dikeringkan selama beberapa hari.\n\nIni adalah rahasia pare Baduy bisa tahan hingga ratusan tahun.",
                result: "Bagus!\n\nSekarang kita jemur pocong hingga kering.",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .ngaleuitkeunPare:
            PhaseContent(
                id: .ngaleuitkeunPare,
                title: "Ngaleuitkeun",
                subtitle: "Menyimpan hasil panen",
                introduction: "Kami menyimpan hasil panen ke dalam leuit (lumbung) untuk kebutuhan di masa mendatang.",
                instruction: "Seret tangga bambu (taraje) ke pintu, lalu perhatikan cara masuk ke leuit.",
                explanation: "Menurut Pikukuh Baduy (hukum adat), pare huma yang disimpan di Leuit tidak boleh dijual atau ditukar.\n\nPare ini hanya boleh disimpan untuk keluarga dan kebutuhan adat.",
                result: "Keren!\n\nKita sudah menyimpan hasil Ngahuma kali ini.\n\nUlangi lagi semua tahapan untuk memenuhi leuit ini.",
                timeCue: nil,
                sourceIDs: ["S3"]
            )
        }
    }
}
