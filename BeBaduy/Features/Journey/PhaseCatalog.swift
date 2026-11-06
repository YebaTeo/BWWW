enum PhaseCatalog {
    static let all: [PhaseContent] = [NukuhContent.value, NgaseukContent.value, NgoredContent.value, DibuatContent.value, NgaleuitkeunPareContent.value]
    static func content(for id: PhaseID) -> PhaseContent { all.first { $0.id == id }! }
}
