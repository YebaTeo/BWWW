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
}
