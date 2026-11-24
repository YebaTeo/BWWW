enum ChapterCard: String, CaseIterable, Hashable, Identifiable {
    // Ordered by the exact timeline a learner earns each card across Cycle 1 and Cycle 2.
    case lebu
    case aseuk, angklung
    case kored, ngubaran
    case etem, saung
    case unjal
    case epic

    case sengon, pungpuhunan, kolecer, garu, lantaian, kematian

    enum Level { case normal, epic }

    var level: Level {
        switch self {
        case .epic, .kematian: .epic
        default: .normal
        }
    }

    var isEpic: Bool { level == .epic }
    var isTool: Bool { self == .aseuk || self == .kored || self == .etem }
    var id: Self { self }
    static let all = allCases
    var artwork: String { self == .epic ? "Card-pernikahan" : "Card-\(rawValue)" }

    var title: String {
        switch self {
        case .lebu: "Lebu (abu pembakaran)"
        case .angklung: "Angklung Buhun"
        case .ngubaran: "Ngubaran Pare (merawat padi)"
        case .saung: "Saung"
        case .unjal: "Unjal"
        case .epic: "Pernikahan"
        case .aseuk: "Aseuk"
        case .kored: "Kored"
        case .etem: "Etem"
        case .sengon: "Pohon Sengon"
        case .pungpuhunan: "Pungpuhunan"
        case .kolecer: "Kolecer"
        case .garu: "Garu"
        case .lantaian: "Lantaian"
        case .kematian: "Kematian"
        }
    }

    var description: String {
        switch self {
        case .lebu: "Dipercaya sebagai pupuk alami yang dapat digunakan untuk menyuburkan tanah dan sesuai dengan penelitian modern."
        case .angklung: "Dimainkan saat perayaan tanam sebagai simbol pernikahan benih pare dan bumi, membawa kegembiraan bagi alam dan seluruh warga."
        case .ngubaran: "Pengobatan pare yang terkena penyakit dengan ramuan alami."
        case .saung: "Pondok untuk beristirahat saat Ngahuma. Terkadang juga digunakan untuk bermalam untuk menjaga pare."
        case .unjal: "Bambu atau kayu untuk mengangkut pare kering ke leuit."
        case .epic: "Pare akan dihaluskan untuk dioleskan ke wajah dan tubuh kedua mempelai sebagai berkat dan pengukuhan perkawinan."
        case .aseuk: "Tongkat kayu yang digunakan untuk membuat lubang tanam."
        case .kored: "Cangkul kecil bermata miring untuk membersihkan gulma dan menggemburkan tanah."
        case .etem: "Alat kecil untuk mipit (mencubit batang padi) saat panen dengan gerakan seperti memetik."
        case .sengon: "Dibiarkan tumbuh liar selama 5–10 tahun sebelum lahan digunakan kembali untuk Ngahuma."
        case .pungpuhunan: "Sekumpulan tanaman obat dan penolak bala yang ditanam di tengah huma yang terbukti bisa menjadi pestisida alami untuk mengusir hama tanaman."
        case .kolecer: "Baling-baling bambu raksasa yang bersuara untuk menghalau kawanan burung dan hama di musim panas saat angin kencang."
        case .garu: "Dibakar oleh tetua adat di tengah huma sebelum panen sebagai bentuk penghormatan kepada pare dan permohonan izin untuk memanennya."
        case .lantaian: "Bambu besar untuk mengangkut pare kering ke leuit. Suara angin yang melewati rongganya dipercaya memberi napas bagi ruh pare."
        case .kematian: "Pare peninggalan mendiang dimasak bersama keluarga dan dibagikan kepada seluruh warga sebagai bentuk berbagi amal semasa hidupnya."
        }
    }

    static func chapter(_ phase: PhaseID, secondCycle: Bool = false) -> Self {
        switch phase {
        case .narawas: secondCycle ? .sengon : .lebu
        case .ngaseuk: secondCycle ? .pungpuhunan : .angklung
        case .ngored: secondCycle ? .kolecer : .ngubaran
        case .mipit: secondCycle ? .garu : .saung
        case .ngalantai: secondCycle ? .lantaian : .unjal
        case .ngaleuitkeunPare: secondCycle ? .kematian : .epic
        }
    }

    static func tool(for phase: PhaseID) -> Self? {
        switch phase {
        case .ngaseuk: .aseuk
        case .ngored: .kored
        case .mipit: .etem
        default: nil
        }
    }

    // These identifiers are also stored in saved collections.
    var imageName: String {
        if self == .epic { return "HumaSunsetValley" }
        if isTool { return "Tool-\(rawValue)" }
        if self != Self.chapter(phase) { return artwork }
        return "Journey-\(phase.rawValue)"
    }

    private var phase: PhaseID {
        switch self {
        case .lebu, .sengon: .narawas
        case .angklung, .pungpuhunan: .ngaseuk
        case .ngubaran, .kolecer: .ngored
        case .saung, .garu: .mipit
        case .unjal, .lantaian: .ngalantai
        case .epic, .kematian: .ngaleuitkeunPare
        case .aseuk: .ngaseuk
        case .kored: .ngored
        case .etem: .mipit
        }
    }

    func isEarned(in progress: JourneyProgress) -> Bool {
        if progress.earnedCardIDs.contains(imageName) { return true }
        guard self == Self.chapter(phase, secondCycle: progress.secondCycle) else { return false }
        return isEpic ? progress.allComplete : progress.record(for: phase).explanationAvailable
    }
}
