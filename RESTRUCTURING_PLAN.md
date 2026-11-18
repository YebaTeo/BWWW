# BeBaduy feature-first folder plan

Group files by the experience a developer is changing, then by their role inside that experience. For example, a change to planting should start in `Features/Chapters/Ngaseuk`, where the screen, planting state, motion detector, and seed renderer are adjacent. Today those files span View/Gameplay, View/Info, Model/ViewModels, Services/Motion, and Asset.

## Recommended structure

Keep the existing iOS 26 SwiftUI app target and MVVM. The app already has chapter view models, injected services, SceneKit renderers, and separate test targets. Physical folders give the team better navigation without adding package dependencies or changing how a learner progresses. This is a maintainability improvement. Runtime performance needs separate measurement.

```text
BeBaduy/
  App/                         entry point, dependency assembly, launch resources
  Features/
    Onboarding/
    Home/
    Journey/                   menu, chapter selection, routing and unlock flow
    Completion/                ending and Leuit discovery
    Collection/                browsing collected cards
    About/                     educational sources
    Chapters/
      Narawas/
      Ngaseuk/
        Views/
        ViewModels/
        Rendering/
        Services/Motion/
        Resources/
      Ngored/
      Mipit/
      Ngalantai/
      NgaleuitkeunPare/
  Shared/
    Learning/                  shared phase definitions, content and session state
    ActivityUI/                common activity layout, controls and lesson container
    DesignSystem/              theme, buttons and reusable visual surfaces
    Rendering/                 scenery and effects used by several experiences
    Services/                  motion, orientation, audio and persistence
BeBaduyTests/                  mirror the owner being tested
BeBaduyUITests/                preserve end-to-end journeys across features
```

Create a type folder only when it has files. A feature with one view can start with just Views. Use the existing NgaleuitkeunPare spelling for the source folder and Leuit in the interface. Keep chapter content centralized in PhaseContent.swift as previously agreed.

## Move map

Paths in the table are relative to the app target. Move directory contents recursively. Apply the named exceptions before the broader directory rules.

| Current source | Proposed destination |
|---|---|
| View/App, Services/App, View/Home/LaunchSplashView.swift | App/Views and App/Dependencies |
| View/Home/IntroductionView.swift, Asset/Onboarding | Features/Onboarding/Views and Resources |
| View/Home/CardCollectionView.swift | Features/Collection/Views |
| View/Home/MenuView.swift, MenuBackground.swift, StageMenuButton.swift, View/Journey | Features/Journey/Views |
| Remaining View/Home, Model/Home, Model/ViewModels/Home | Features/Home/Views, Models, ViewModels respectively |
| Model/Journey, Model/ViewModels/Journey | Features/Journey/Models and ViewModels |
| Model/Content/About | Features/About/Models |
| View/Completion, Model/ViewModels/Completion | Features/Completion/Views and ViewModels. The discovery carousel belongs to the ending even though it depicts Leuit. |
| View/Gameplay/<chapter>, View/Info/<chapter>, Model/ViewModels/<chapter> | Features/Chapters/<chapter>/Views or ViewModels. Place chapter-specific 3D wrappers and field artwork in Rendering. |
| Model/Shared/NarawasPlot.swift | Features/Chapters/Narawas/Models |
| Model/Shared/MotionSample.swift, Services/Motion/Shared, Services/Motion/Narawas | Shared/Services/Motion. Ngored also consumes NarawasLookMotion. |
| Remaining Model/Shared | Shared/Learning/Models, including PhaseID, PhaseContent, LandscapeState, JourneyProgress and PhaseSessionState |
| Model/ViewModels/Shared/ActivityCardState.swift | Shared/ActivityUI/Models |
| Services/Motion/Ngaseuk, Services/Ngored | Ngaseuk/Services/Motion and Ngored/Services inside Features/Chapters. Keep NgaseukUITestMotion available to the app’s existing UI-test launch path. |
| Services/Rendering/Mipit | Features/Chapters/Mipit/Rendering |
| Services/Rendering/Home, Services/Rendering/Shared | Shared/Rendering/Huma and Shared/Rendering/Common. HomeSceneRenderer also supports chapter visuals. Move the file intact first. |
| Services/Rendering/Narawas | Features/Chapters/Narawas/Rendering. Review shared renderer helpers independently before extracting them. |
| Services/Orientation, Audio, Persistence | Shared/Services/Orientation, Audio, Persistence. The app entry point and Ngalantai both use orientation handling. |
| View/Theme, View/Components/LessonButton.swift, HumaGlassCard.swift | Shared/DesignSystem/Theme and Components |
| Remaining View/Components | Shared/ActivityUI/Views, including ActivityCardStyle, ToolRevealCard and PhaseContainerView |
| Asset/Home | Shared/Rendering/Huma/Resources. Keep the PoCPadi catalog and lumbung model together for the first move. |
| Asset/HumaGlass.xcassets, Asset/Assets.xcassets | Shared/DesignSystem/Resources and App/Resources respectively |
| Asset/{Narawas,Ngaseuk,Ngored,Mipit,NgaleuitkeunPare} | Corresponding chapter’s Resources. Move whole catalogs, including Contents.json and variants. Mipit currently contains drying artwork used later in the journey. Keep the catalog intact until asset ownership is audited separately. |
| LaunchScreen.storyboard, PrivacyInfo.xcprivacy | App/Resources. Check the compiled launch storyboard and privacy manifest in the archive. |

## Tests, tools, and repository files

- Keep both test target roots. Move chapter unit tests under BeBaduyTests/Features/Chapters/<chapter>. Place ProgressStoreTests under Shared/Services/Persistence and ThemeResourceTests under Shared/DesignSystem. Put JourneyTests and LessonFlowTests under Features/Journey, and LeuitDiscoveryTests under Features/Completion. Read each case in the multi-chapter ActivityTests before splitting it. HomeUITests and JourneyUITests already have clear owners.
- Keep the Xcode project, scheme, Git files, skills directories, scripts and original artwork backups at repository level. Keep logo.png and realistic-artwork.json with the existing tooling until their consumers have been verified. Update asset paths in the manifest, scripts/create_app_icon.swift and scripts/generate_huma_artwork.swift wherever affected.
- Keep README.md and ARCHITECTURE.md discoverable at the root. Update the architecture map and stale five-chapter descriptions after migration. docs/ contains historical material and is ignored by Git in this checkout. Keep the migration plan at repository root so it can be reviewed.

## Migration sequence and checks

1. Record the current Git status and baseline build/test results. Preserve existing uncommitted work. Xcode uses filesystem-synchronized roots for BeBaduy, BeBaduyTests, and BeBaduyUITests. Move files within those roots and inspect target membership. Regenerating the project with the legacy scaffolding script would overwrite project settings.
2. Pilot Ngaseuk. Move its Swift files first, with unchanged filenames and declarations. Build app and tests, then run the motion tutorial, seed drag, and planting-help flows. This exercises view, state, rendering and service ownership together.
3. Move the other five chapters in small batches. Verify Narawas cutting, Ngored camera motion, Mipit pinch, Ngalantai rotation and Leuit ladder placement. Keep saved phase keys such as ngahuru, dibuat and ngaleuitkeun_pare stable. Check an existing saved journey as well as a new one.
4. Move Home, Journey, Onboarding, Completion, Collection and About. Then move shared components and app assembly. Check fresh launch, returning launch, locked chapters, activity replay from the tool card, and the final card reveal. Keep screen state, gesture handlers and view identities intact during moves.
5. Move resources last. Search the whole repository for old paths, including bundle lookups with subdirectory arguments, generators, previews and tests. Keep asset names, raw filenames and catalog namespaces stable. Verify models, audio, launch art, and chapter images from a built app. Review the archive’s app icon and privacy manifest.
6. Finish with a clean build, unit and journey UI tests, and a rename-aware diff. Report any baseline failures separately. If a batch fails, repair or revert that batch before moving another feature.

**Later cleanup.** StageThumbnailStore currently lives at the bottom of HomeSceneRenderer.swift. Once the folder moves have landed, consider extracting menu thumbnail ownership into Journey while keeping the rendering API in Shared/Rendering. Separating that change makes regressions easier to trace.
