import SwiftUI
import Observation

@Observable @MainActor final class ActivitySheetState {
    static let compact = PresentationDetent.height(110)
    var detent: PresentationDetent = .medium
    var largeText = false
    private(set) var contentRevision = 0
    var compactDetent: PresentationDetent { largeText ? .height(160) : Self.compact }
    var collapsed: Bool { detent == Self.compact || detent == .height(160) }
    func expand() { detent = largeText ? .large : .medium; contentRevision += 1 }
    func collapse() { detent = compactDetent }
}

