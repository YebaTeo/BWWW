enum PhaseCatalog {
    static let all: [PhaseContent] = [NarawasContent.value, NyacarContent.value, NgaganggangContent.value,
        NgahuruContent.value, NgaseukContent.value, NgoredContent.value, NgubaranPareContent.value,
        DibuatContent.value, DryingRiceContent.value, NgunjalContent.value, NgaleuitkeunPareContent.value]
    static func content(for id: PhaseID) -> PhaseContent { all.first { $0.id == id }! }
}
