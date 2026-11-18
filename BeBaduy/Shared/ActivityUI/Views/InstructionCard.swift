import SwiftUI

struct ActivityContinuation {
    let title: String
    let identifier: String
    let action: @MainActor () -> Void
}

struct ActivityContinuationKey: PreferenceKey {
    static var defaultValue: ActivityContinuation? { nil }

    static func reduce(value: inout ActivityContinuation?, nextValue: () -> ActivityContinuation?) {
        if let next = nextValue() { value = next }
    }
}

/// Supplies the tap action to the surrounding activity layout while the visible hint is temporary.
struct ActivityAcknowledgement: View {
    let title: String
    let identifier: String
    let action: () -> Void

    @State private var showsHint = true
    @State private var acknowledged = false

    var body: some View {
        Group {
            if showsHint {
                hint.accessibilityIdentifier("activity.continuation.hint")
            } else {
                hint.hidden()
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
        .preference(key: ActivityContinuationKey.self, value: ActivityContinuation(
            title: title, identifier: identifier, action: acknowledge
        ))
        .task {
            showsHint = true
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            showsHint = false
        }
    }

    private var hint: some View {
        Text("Tap layar untuk lanjut")
            .font(.callout.italic())
            .foregroundStyle(AppTheme.cream)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.75), radius: 2, y: 1)
    }

    private func acknowledge() {
        guard !acknowledged else { return }
        acknowledged = true
        action()
    }
}
