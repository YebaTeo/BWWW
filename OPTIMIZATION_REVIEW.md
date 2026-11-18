# BeBaduy optimization review

Reviewed November 18, 2026 at revision `7f80a31`. This is a static review of the project inventory, with closer inspection of scene construction, menu navigation, activity rendering, assets, tests, and documentation. File sizes below are source sizes on disk. Launch time, frame time, energy use, decoded texture memory, and App Store download size require separate measurements.

## 1. Measure the first interactive Home frame, then defer later chapter scenery

[HomeSceneRenderer.swift](BeBaduy/Shared/Rendering/Huma/HomeSceneRenderer.swift), particularly `buildScene()`, is the first place to investigate the wait after onboarding. One synchronous setup builds the forest, fire, ash, planting area, rice, harvest targets, drying rack, granary, and Leuit props before it installs the display link. The granary builder can also load a scene from disk. A first-time learner sees Narawas, yet setup already pays for later chapters. The renderer is 4,707 lines, but the actionable issue is the work on this path.

**First experiment.** Add timing intervals around Home construction, the individual builders, and the first frame that accepts input. On a physical iPhone, capture five Release runs without the debugger for first entry after onboarding and five for a returning learner. Record the median and slowest run. If later-stage construction dominates, move the costliest group behind a build-once guard and prepare it before the transition that first needs it. Build the correct group immediately when restoring a late chapter. Check forward transitions, replay, and direct entry to Leuit for missing props or a new hitch.

## 2. Generate the chapter menu pictures before shipping

[JourneyView.swift](BeBaduy/Features/Journey/Views/JourneyView.swift) calls `ensureLoaded()` when the menu appears. In [StageThumbnailStore](BeBaduy/Shared/Rendering/Huma/HomeSceneRenderer.swift), a cache miss constructs another complete Home scene, renders up to six snapshots, composites them, and encodes JPEGs on the main actor. Disk reads and writes already run separately. The initial delay lets presentation start, but the expensive work can still coincide with scrolling. Cached visits take a different path, which can hide the problem during development.

**Suggested change.** Export the six existing compositions using the current renderer, store them as menu assets, and use those images directly. The menu already displays static thumbnails, so this preserves its current look and leaves the interactive 3D Home experience intact. Compare all six crops and locked states against the current menu. Measure first-open latency and scrolling with an empty cache, then reopen the menu. Account for the added image bytes in the release build.

## 3. Stop decorative rendering when it cannot help the learner

[Ngaseuk’s seed bowl](BeBaduy/Features/Chapters/Ngaseuk/Rendering/RiceSeed3DView.swift) enables continuous rendering, runs a 60 Hz display link to bob and rotate a grain, and adds a repeating SwiftUI pulse when interactive. Teardown already invalidates the link. The opportunity is the interval while the bowl remains mounted but idle, covered by help, or shown with Reduce Motion. The [seed close-up](BeBaduy/Features/Chapters/Ngaseuk/Rendering/SeedPeek3DSceneView.swift) already switches continuous rendering according to whether seeds are pouring.

Start with an explicit decoration-active condition for the bowl. Pause decorative movement with Reduce Motion and while covered or inactive. Keep the planting gesture and its feedback responsive. Compare GPU/frame activity over 30 seconds of idle seeding, then test a drag, a pour, reopening help, and returning from the background. Preserve the existing close-up preloading that avoids constructing a scene during a drag.

## 4. Optimize the assets that actually cost memory or download size

The asset directory occupies about 75 MiB on disk. Some of the largest source files are the Narawas ash image (4.5 MiB), the granary model (4.5 MiB), the terrain texture (4.4 MiB), and the tool card weave (2.9 MiB). PNG file size alone does not predict GPU memory. Compare each image’s pixel dimensions with its largest displayed size and inspect its use as a texture, especially alpha edges, before changing resolution or encoding.

A hash check found identical PNG bytes in the `HumaYoungRice` and `HumaGrassTexture` image sets. Check whether both names intentionally represent different art roles before consolidating. Measure the compiled app to determine actual savings. The approximately 37 MiB in `scripts/original_artwork_backup` is outside the app source directory. Removing it would primarily reduce checkout size. Use an exported, thinned Release build to judge download savings.

## 5. Keep developer guidance aligned with the six-phase experience

[README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md) still describe five stages, and the README presents a draggable activity sheet and demonstrations as current. [PhaseID.swift](BeBaduy/Shared/Learning/Models/PhaseID.swift) defines six phases, and the shared activity UI uses [ActivityCardPanel](BeBaduy/Shared/ActivityUI/Views/ActivityCardStyle.swift). Update those two entry documents and mark older design plans as historical wherever they are linked. Document the distinction between the display names and legacy resource keys such as `dibuat`. A future cleanup based on the README alone could accidentally break chapter resources or replay.

## Verification and order of work

1. Capture baseline timings for onboarding → interactive Home, first and repeat menu opening, and idle Ngaseuk on the same iPhone, iOS version, and build configuration. The existing journey and phase tests cover behavior. Add performance measurements alongside them where they can be repeated reliably.
2. Ship the menu thumbnail change as an isolated experiment. It has a clear visual comparison and avoids runtime scene generation on a cache miss.
3. Use the Home builder timings to select the first group to defer. Check initial launch and transitions separately so a faster Home does not simply move the wait into the next chapter.
4. Tune the bowl and texture sizes independently. Compare before/after traces, screenshots, and the exported build size for each change.

This review made no runtime measurements or changes to application code.
