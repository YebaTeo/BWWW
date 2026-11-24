# BeBaduy

An offline iOS learning app in SwiftUI and SceneKit that introduces **Ngahuma** — the traditional Baduy shifting rice-farming cycle, from clearing the *huma* (dryland field) to storing the harvest in the *leuit* (granary).

Built natively for iPhone (**iOS 26.0+**) with **zero third-party dependencies**, no account, no camera access, and no network requests.

---

## Highlights

- **Six interactive 3D chapters** guided by touch, gestures, orientation, and CoreMotion sensors (with touch/VoiceOver fallbacks).
- **Woven-glass cultural explanations (`HumaGlassCard`)** after every activity sharing Baduy agricultural wisdom and *Pikukuh* traditions.
- **Collectible card gallery (`Koleksi`)** with **15 live-rendered cards** — 6 Cycle 1 cultural cards, 3 traditional tool cards (*Aseuk*, *Kored*, *Etem*), and 6 Cycle 2 cards unlocked when starting a new cycle.
- **Manual replay & multi-cycle progression:** Completing all 6 chapters keeps every stage open to revisit and unlocks **"Mulai ngahuma lagi"** at the bottom of the journey map to reset stages for the next cycle while preserving all earned cards.
- **Hardware-aware Metal rendering:** Pre-warmed 3D stage previews and fields (`PreparedStagePreview`, `NgahumaScene`), shared USDZ tool cache (`ToolSceneSource`), thermal/Low Power Mode frame pacing (`SceneFrameBudget`), and background-thread audio playback (`ActivityAudio`, `FirePlayback`).

---

## Six-Chapter Flow

| # | Chapter | Activity & Cultural Focus |
|---|---|---|
| 1 | **Narawas** | Look around the 3D clearing, swipe to fell trees with a *golok*, then ignite dry brush (*Ngahuru*) to enrich the soil with ash (*lebu*). |
| 2 | **Ngaseuk** | Flip the **Aseuk** tool card, thrust downward (or tap) to dibble three planting holes, then tilt or drag to pour 4 rice seeds into each hole. |
| 3 | **Ngored** | Flip the **Kored** tool card, look around the growing field, and swipe out weeds across rain and day/night growth cycles. |
| 4 | **Mipit** | Flip the **Etem** tool card and pinch to harvest ripe *pare huma* stalks. |
| 5 | **Ngalantai** | Rotate to landscape and tilt to balance harvested *pocong* on the bamboo drying rack (*Lantaian*) for 7 seconds, then return to portrait to dry. |
| 6 | **Ngaleuitkeun** | Drag the bamboo ladder (*taraje*) to the *leuit* door, watch the harvest stored inside, read the *Pikukuh Baduy* reflection and cycle summary, and unlock the granary reward card. |

---

## Requirements & Running Locally

- **Xcode:** 26 or later
- **Deployment Target:** iOS 26.0 (iPhone)
- **Frameworks:** SwiftUI, Observation, SceneKit, Metal, CoreMotion, AVFoundation, UIKit

### Open & Run in Xcode
1. Open `BeBaduy.xcodeproj`.
2. Select the **BeBaduy** scheme and an installed iPhone Simulator (or a physical iPhone — keep the existing signing settings for device builds).
3. Press **Run** (`⌘R`).

> **Note on project files:** The project uses Xcode filesystem-synchronized roots (`BeBaduy`, `BeBaduyTests`, `BeBaduyUITests`). Add or remove files directly inside their feature folders and Xcode will pick them up automatically. Do **not** run legacy `scripts/generate_project.py` over the current project, as it overwrites project settings.

### Build & Run Tests from Terminal
```bash
# Build app and tests for iOS Simulator
xcodebuild -project BeBaduy.xcodeproj -scheme BeBaduy \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  build-for-testing

# Run unit tests on a Simulator (replace destination with an installed simulator name/ID)
xcodebuild -project BeBaduy.xcodeproj -scheme BeBaduy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BeBaduyTests test
```

> Simulator runs cover logic, persistence migration, scene lifetime, and motion state machines, but physical-iPhone testing is still recommended for CoreMotion comfort, haptics, Rotation Lock behavior, and real Metal load timings.

---

## Architecture

BeBaduy uses a **feature-first MVVM** structure. See [ARCHITECTURE.md](ARCHITECTURE.md) for the full folder responsibility map.

```text
BeBaduy/
├── App/                  # Entry point, launch screen, PrivacyInfo.xcprivacy, main assets
├── Features/
│   ├── About/            # Internal research source catalog (SourceCatalog.swift)
│   ├── Chapters/         # Narawas, Ngaseuk, Ngored, Mipit, Ngalantai, NgaleuitkeunPare
│   ├── Collection/       # Koleksi gallery, ChapterCard catalog, live card renderer
│   ├── Completion/       # Cycle completion summary model
│   ├── Home/             # Landing transition, stage previews, reward cards, tab bar
│   ├── Journey/          # Journey map (MenuView), navigation, progress & flow VMs
│   └── Onboarding/       # Story introduction views
└── Shared/
    ├── ActivityUI/       # PhaseContainerView, ToolRevealCard, ActivityCardStyle
    ├── DesignSystem/     # AppTheme, HumaGlassCard, LessonButton, loading indicators
    ├── Learning/         # PhaseContent, PhaseID, JourneyProgress, session state
    ├── Rendering/        # HomeSceneRenderer, SceneFrameBudget, ToolSceneSource, USDZ/art
    └── Services/         # CoreMotion (FieldLookSession), Orientation, Audio, Persistence
```

---

## Persistence & Privacy

- **100% local & offline:** Learning progress (`BeBaduy.journey.v2`) and card reveal state (`BeBaduy.collection.arranged.v1`) are stored strictly on-device in `UserDefaults`.
- **Safe migration & recovery:** Upgrading from `BeBaduy.journey.v1` preserves completed compatible chapters without modifying legacy keys. Corrupted save payloads are backed up locally under `*.recovery` keys.
- **Privacy manifest:** [PrivacyInfo.xcprivacy](BeBaduy/App/Resources/PrivacyInfo.xcprivacy) declares local `UserDefaults` usage only. There are no analytics SDKs, trackers, camera feeds, or network upload paths.

---

## Cultural & Content Notes

- **Educational representations:** The six-chapter sequence, 3D vegetation, and counts of trees, holes, weeds, and granaries are simplified interactive choices rather than customary prescriptions. Preparation groups clearing and burning (*Ngahuru*) without labeling burning itself as "Narawas."
- **Sources:** Research references are maintained internally in `SourceCatalog.swift`.
- **Audio:** Virtual fire audio (`ngahuma-fire.wav`, `ngahuma-ignite.wav`) is bundled alongside lightweight synthesized sound cues for cutting, digging, seeding, weeding, harvesting, bamboo balancing, and rain. These cues are illustrative rather than documentary recordings; Angklung audio is not bundled pending an appropriate recording and reuse rights.
