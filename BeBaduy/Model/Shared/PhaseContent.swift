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
                introduction: "Kenali persiapan lahan huma, dari menebas tumbuhan hingga perubahan lahan setelah pembakaran.",
                instruction: "Ketuk \(NarawasPlot.count) pohon contoh, lalu ketuk setiap petak untuk menyalakan api virtual.",
                explanation: "Bab persiapan ini merangkum penebasan dan pembakaran. Pembakaran hasil tebasan dikenal sebagai ngahuru; kegiatan ini mengikuti pengetahuan dan aturan adat. Enam pohon pada layar adalah alat bantu belajar, bukan jumlah atau petunjuk praktik di lapangan.",
                result: "Api telah mereda dan lahan berubah.",
                timeCue: nil,
                sourceIDs: ["S1", "S5"]
            )
        case .ngaseuk:
            PhaseContent(
                id: .ngaseuk,
                title: "Ngaseuk",
                subtitle: "Membuka tempat untuk benih",
                introduction: "Kenali aseuk, tongkat untuk membuat lubang tanam.",
                instruction: "Gerakkan ponsel perlahan dari atas ke bawah untuk membuat tiga lubang, lalu masukkan benih.",
                explanation: "Aseuk membuat lubang tanpa membajak tanah. Penempatan benih dilakukan setelah lubang tersedia. Kegiatan menanam melibatkan kerja bersama; pertumbuhan tetap membutuhkan waktu, hujan, dan perawatan.",
                result: "Tiga lubang berisi benih.",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .ngored:
            PhaseContent(
                id: .ngored,
                title: "Ngored",
                subtitle: "Merawat padi muda",
                introduction: "Padi muda tumbuh bersama tumbuhan lain.",
                instruction: "Gunakan kored untuk membersihkan delapan gulma contoh di sekitar padi.",
                explanation: "Ngored menggunakan kored untuk membersihkan gulma di sekitar padi. Penyiangan mengurangi persaingan tumbuhan lain dengan padi dan dilakukan berulang selama pertumbuhan. Padi huma mengandalkan air hujan. Waktu berladang mengikuti musim serta pengetahuan dan kalender adat.",
                result: "Gulma berkurang; padi muda tetap tumbuh.",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .mipit:
            PhaseContent(
                id: .mipit,
                title: "Mipit",
                subtitle: "Memanen padi",
                introduction: "Padi menguning setelah melewati masa pertumbuhan.",
                instruction: "Cubit padi dengan dua jari untuk memanen.",
                explanation: "Etem atau ani-ani digunakan untuk memanen malai bersama tangkainya.",
                result: "Padi berhasil dipanen!",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .ngalantai:
            PhaseContent(
                id: .ngalantai,
                title: "Ngalantai",
                subtitle: "Mengeringkan padi",
                introduction: "Ikatan padi yang telah dipanen disiapkan untuk dikeringkan.",
                instruction: "Putar ponsel, lalu jaga bambu tetap rata selama tiga detik.",
                explanation: "Padi dikeringkan sebelum disimpan di leuit. Latihan keseimbangan membantu mengenali ikatan padi dan bambu penjemur.",
                result: "Padi siap dikeringkan di rak bambu.",
                timeCue: nil,
                sourceIDs: ["S1", "S2"]
            )
        case .ngaleuitkeunPare:
            PhaseContent(
                id: .ngaleuitkeunPare,
                title: "Leuit",
                subtitle: "Menyimpan hasil panen",
                introduction: "Padi yang telah kering dibawa ke tempat penyimpanan.",
                instruction: "Seret ikatan ke tiga leuit contoh, lalu lihat bagian dalamnya.",
                explanation: "Leuit menyimpan padi sebagai cadangan pangan rumah tangga dan untuk keperluan adat. Padi disimpan bersama tangkainya. Tiga bangunan dan posisi ikatan pada aktivitas hanyalah alat bantu belajar.",
                result: "Padi tersimpan di leuit.",
                timeCue: nil,
                sourceIDs: ["S3"]
            )
        }
    }
}
