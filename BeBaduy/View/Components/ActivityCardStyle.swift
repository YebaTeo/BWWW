import SwiftUI

/// The scene may extend under system chrome. Its informational overlays still use these insets.
extension EnvironmentValues {
    @Entry var activitySceneInsets = EdgeInsets()
}

enum ActivityCardPlacement {
    case middle, bottom

    var alignment: Alignment { self == .middle ? .center : .bottom }
}

struct ActivityCardLayout<Content: View>: View {
    let placement: ActivityCardPlacement
    var sceneInsets = EdgeInsets()
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 12, content: content)
            .frame(maxWidth: 400)
            .padding(.leading, 24 + sceneInsets.leading)
            .padding(.trailing, 24 + sceneInsets.trailing)
            .padding(.top, sceneInsets.top)
            .padding(.bottom, 16 + sceneInsets.bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: placement.alignment)
            .backgroundPreferenceValue(ActivityContinuationKey.self) { continuation in
                if let continuation {
                    Button(action: continuation.action) {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(continuation.title)
                    .accessibilityIdentifier(continuation.identifier)
                    .accessibilityActivationPoint(UnitPoint(x: 0.5, y: 0.15))
                }
            }
            .preference(key: ActivityContinuationKey.self, value: nil)
    }
}

/// The shared glass surface holds information. Interactive controls are siblings in the layout.
struct ActivityCardPanel<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .body) private var bodySize = 20.0
    var passesTouchesThrough = false
    var previewsOpaqueSurface = false
    @ViewBuilder var content: () -> Content

    private let outline = Color(red: 251.0 / 255, green: 208.0 / 255, blue: 163.0 / 255) // #FBD0A3
    private let warmSurface = Color(red: 81.0 / 255, green: 66.0 / 255, blue: 54.0 / 255)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        ViewThatFits(in: .vertical) {
            contents.fixedSize(horizontal: false, vertical: true)
                .allowsHitTesting(false)
            ScrollView {
                contents.fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("activity.card.scroll")
        }
        // Long live hints scroll in a bounded area so large text leaves the field usable.
        .frame(maxHeight: passesTouchesThrough && dynamicType.isAccessibilitySize ? 200 : nil)
        .background {
            Group {
                if reduceTransparency || contrast == .increased || previewsOpaqueSurface {
                    shape.fill(warmSurface)
                } else {
                    // Let the scene show through the material instead of covering it with gray.
                    shape.fill(.clear)
                        .glassEffect(.regular.tint(warmSurface.opacity(0.24)), in: shape)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay { shape.strokeBorder(outline, lineWidth: 1).allowsHitTesting(false) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity.navigation.card")
    }

    private var contents: some View {
        VStack(spacing: 12, content: content)
            .font(.system(size: bodySize, design: .rounded))
            .foregroundStyle(AppTheme.cream)
            .multilineTextAlignment(.center)
            .padding(28)
            .frame(maxWidth: .infinity)
    }
}

struct ActivityCardHeading: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .fontWeight(.semibold)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ActivityCardPreview: View {
    var placement: ActivityCardPlacement = .middle
    var isStatus = false
    var message = "Arahkan ponsel ke sekeliling dan perhatikan proses pembakaran."
    var backdrop = "HumaEnvironment"
    var opaque = false

    var body: some View {
        ZStack {
            LessonBackdrop(asset: backdrop)
            ActivityCardLayout(placement: placement) {
                ActivityCardPanel(previewsOpaqueSurface: opaque) {
                    Text(message)
                    if isStatus {
                        ProgressView(value: 0.65)
                            .tint(AppTheme.orange)
                            .accessibilityLabel("Waktu seimbang")
                    }
                }
                if !isStatus {
                    ActivityAcknowledgement(title: "Lanjut", identifier: "preview.continue") {}
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Card · middle instruction") {
    ActivityCardPreview()
}

#Preview("Card · warm glass reference") {
    ActivityCardPreview(placement: .bottom,
                        message: "Arahkan ponselmu ke sekeliling, lalu ketuk pohon-pohon di sekitarmu untuk menebangnya.")
}

#Preview("Card · bottom status, landscape", traits: .landscapeLeft) {
    ActivityCardPreview(placement: .bottom, isStatus: true,
                        message: "Seimbang · tahan sebentar", backdrop: "LaunchLandscape")
}

#Preview("Card · long conclusion, large text") {
    ActivityCardPreview(message: PhaseContent.content(for: .ngaleuitkeunPare).result,
                        backdrop: LandscapeState(phase: .ngaleuitkeunPare, isResult: true).assetName)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Card · Reduce Transparency") {
    ActivityCardPreview(placement: .bottom, isStatus: true, message: "Rumput dicabut: 2/4", opaque: true)
}
