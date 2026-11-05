# BeBaduy

A native, offline SwiftUI iPhone learning prototype: 11 short activities following rice from a huma to a leuit. Indonesian text retains Sundanese activity names. Deployment target: iOS 26+. No external packages, accounts, server, or purchases.

## Scrolling pilot

Select **BeBaduy Story Pilot** in Xcode and Run in Debug to try the isolated Ngaseuk → Ngored illustrated story. Or open the canvas preview in `StoryPilotView.swift`. Scroll instead of using start/next buttons; tap the soil directly. The prototype uses only in-memory progress and stops at Ngored's introduction. The normal **BeBaduy** scheme retains the existing eleven-phase app and saved progress. See [pilot instructions and architecture](docs/STORY_PILOT.md).

## Platform and UX direction

BeBaduy requires iOS 26 or later and Xcode 26 or later. App, unit-test, and UI-test deployment targets are kept in sync by `scripts/generate_project.py`. Earlier iOS versions cannot install this build.

Next UX priorities: give the 3D field more visible space, keep essential navigation controls easy to reach, and connect meaningful scene interactions to the farming modules. Use native glass for controls selectively while keeping explanation text legible. These are follow-up design priorities, not features automatically enabled by raising the deployment target. Preserve Reduce Motion, large text, accessible alternatives, and camera-free operation.

## Harvest home screen

Home integrates the supplied PoCPadi sunset scene, procedural RealityKit rice, and four visual milestones (Nukuh, Ngaseuk, Ngored, Dibuat). Swipe the field or use the four stage buttons to preview growth. **Mulai belajar / Lanjutkan belajar** opens the saved learning phase; **Perjalanan** opens all eleven modules and About. Previewing or replaying the field does not unlock activities or change saved progress. The card scrolls for larger text, and ambient motion pauses with Reduce Motion, while the app is inactive, and while another screen is open. Only the three required images and the active rice scene were imported; prototype build outputs and alternate scenes are excluded.

## Camera-free Ngahuma 3D

Choose **Jelajahi huma 3D** from Home to explore the imported Ngahuma scene without opening the camera. Drag to look around and tap plots, or use **Petak berikutnya**. This optional overview leaves learning progress unchanged. See [implementation and resource notes](docs/NGAHUMA_3D.md).

## Run

1. Open `BeBaduy.xcodeproj` in Xcode 26+ (verified with Xcode 27.0).
2. Select the **BeBaduy** scheme and an installed iPhone simulator, then Run.
3. For an iPhone, select a signing team and a unique bundle identifier. Motion quality must be checked on hardware.

If the active toolchain points to Command Line Tools, use an explicit Xcode directory:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl list devices available
xcodebuild -project BeBaduy.xcodeproj -scheme BeBaduy \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=27.0' \
  -derivedDataPath /private/tmp/BeBaduyDerived CODE_SIGNING_ALLOWED=NO test
```

Choose a destination installed on your machine. `BeBaduyTests` covers the models and services; `BeBaduyUITests` walks the full touch journey, demonstration, replay, resume, and large text layouts. UI tests use a separate UserDefaults suite in Debug, leaving ordinary app progress intact.

## Learning flow

Home → full-screen phase introduction → swipe up to the activity → complete it or observe the demonstration → swipe to its explanation → swipe to the next phase. Each swipe advances at most one page. Long activities and large text scroll within their page; a separate swipe area below that content moves between pages. The last phase leads to the completion screen. Activities never navigate or scroll automatically. Every activity also offers **Lihat demonstrasi**. Completing either path unlocks the next activity; it does not claim the explanation was read.

Reopening a completed phase restores its explanation. **Ulangi aktivitas** resets only temporary activity state. An interrupted replay retains completion. Relaunching an unfinished phase restarts its short activity from the introduction at the saved phase.

## Architecture

- `App`: stable app dependencies, one shared motion service, root SwiftUI scene.
- `Features/Home`, `Journey`, `Completion`, `About`: navigation, catalog, local progress authority, final reflection, source information.
- `Features/Phases/<Phase>`: each owns its main view, introduction, activity, description, observable main-actor view model, typed content, and unique resource catalog. Ngaseuk also owns its gesture detector. Validation/counting lives in these models.
- `Shared`: small presentation containers, semantic chronological landscape states, progress records, persistence service, motion service, adaptive theme. `PhaseSessionState` only manages introduction/active/reflection presentation; it does not implement activity rules.
- `JourneyViewModel` is the single in-memory durable progress authority. `ProgressStore` saves a versioned Codable record under stable IDs in UserDefaults after meaningful actions. Both observation and performance flags are retained. Missing data starts fresh; corrupt, inconsistent, or incompatible records are backed up under a recovery key and explained to the user.

No shared mutable landscape exists: every phase has its own before/result assets. Phase resources are bundled, including schematic plant references; learning needs no network. Research references remain internal; the app displays no bibliography links.

## Motion

Ngaseuk works entirely with taps. The learner explicitly starts optional motion; a downward acceleration projected onto gravity is sent to the same validated planting method as touch. Neutral rearming and a 0.65-second cooldown suppress jitter/repeated input. One `CMMotionManager` supplies device-motion updates at 40 Hz. Hardware absence/errors return the learner to touch. Generation tokens ignore queued callbacks after stopping.

Updates stop on completion, demonstration, switching to touch, phase exit, and inactive/background transitions. Foregrounding does not restart motion. `NSMotionUsageDescription` is included in generated app Info.plist. The app does not request motion history, activity recognition, or pedometer data; do not assume a particular permission dialog for live device-motion updates. See Apple's [CMMotionManager](https://developer.apple.com/documentation/coremotion/cmmotionmanager) and [motion purpose string](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription).

## Resources and project maintenance

The checked-in Xcode project includes app, unit-test, and UI-test targets and shared schemes. It uses Xcode 16+ filesystem-synchronized folders: new Swift files and asset catalogs under each target root are included automatically. The navigator shows blue folders and filename-only Swift entries. There is no third-party project-generation dependency. To regenerate project settings, run:

```sh
python3 scripts/generate_project.py
```

`create_artwork.py` regenerates original simple vector landscape assets. `create_app_icon.swift` draws the original leuit icon using AppKit. The content/view scaffolding scripts reflect the initial authoring input; rerunning them overwrites their generated phase files. Edit phase Swift files directly for normal development.

## Sources and review

Source titles, links, and per-phase references are retained internally in `SourceCatalog.swift`. Research and review details: [docs/CONTENT_REVIEW.md](docs/CONTENT_REVIEW.md). The project's original requirements remain in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) and [docs/CODEX_BUILD_PROMPT.md](docs/CODEX_BUILD_PROMPT.md).

The 11 modules are an educational arrangement, not a universal cultural classification. Counts, simplified illustrations, field-map constraints, and placement slots are interface choices. This is an unreviewed cultural prototype, with no claim of community approval. See [docs/VERIFICATION.md](docs/VERIFICATION.md) for actual checks and the remaining physical-device, accessibility, and cultural review work.
