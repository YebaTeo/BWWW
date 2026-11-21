import SwiftUI

struct NgalantaiActivitySurface: View {
    let model: NgalantaiViewModel
    @State private var balancedFeedback = 0
    private enum CueSide { case left, right }

    private var activeCueSide: CueSide? {
        guard model.step == .balancing else { return nil }
        if model.balance >= NgalantaiViewModel.balanceTolerance { return .left }
        if model.balance <= -NgalantaiViewModel.balanceTolerance { return .right }
        return nil
    }

    private var isBalanced: Bool {
        model.step == .balancing && abs(model.balance) < NgalantaiViewModel.balanceTolerance
    }

    var body: some View {
        ZStack {
            if model.step == .balancing {
                HStack {
                    imbalanceCue(isLeft: true)
                    Spacer()
                    imbalanceCue(isLeft: false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .task(id: isBalanced) {
            guard isBalanced else { return }
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard isBalanced else { return }
            balancedFeedback += 1
        }
        .sensoryFeedback(.alignment, trigger: balancedFeedback)
        .sensoryFeedback(.impact(weight: .light), trigger: activeCueSide) { _, side in
            side != nil
        }
    }

    private func imbalanceCue(isLeft: Bool) -> some View {
        let active = activeCueSide == (isLeft ? CueSide.left : CueSide.right)
        let intensity = min(1, abs(model.balance) / 0.5)
        return VStack(spacing: 8) {
            Image(systemName: "arrow.down")
                .font(.system(size: 30, weight: .bold))
            Text(isLeft ? "Kiri turun" : "Kanan turun")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [.orange.opacity(0.25 + intensity * 0.45), .clear],
                startPoint: isLeft ? .leading : .trailing,
                endPoint: isLeft ? .trailing : .leading
            )
        }
        .opacity(active ? 1 : 0)
        .accessibilityHidden(!active)
    }
}
