# BeBaduy

Offline SwiftUI learning app for iPhone, iOS 26+. Five chapters introduce rice farming from huma to leuit. No camera, account, server, or third-party packages are required.

## Run

Open `BeBaduy.xcodeproj`, select the **BeBaduy** scheme and an installed iPhone simulator, then Run. Use Xcode 26 or later. Keep the project's existing signing settings when building for a device.

The project uses filesystem-synchronized folders. Add or remove files directly in their feature folders; Xcode discovers them automatically. `scripts/generate_project.py` is legacy scaffolding and must not be run over the current project because it replaces project settings.

## Five-chapter flow

| Chapter | Activity sequence |
| --- | --- |
| Nukuh | Cut six example trees in a camera-free 3D field → acknowledge the result → observe virtual burning and the changed field |
| Ngaseuk | Meet the aseuk → instructions → make three holes by touch or gentle phone motion → acknowledge → drag or tap seeds into holes |
| Ngored | Remove eight example weeds, retaining rice → acknowledge → observe rain |
| Dibuat | Meet the etem → pinch or tap four rice heads → balance bundles using tilt or touch → learn about drying |
| Leuit | Drag or select three bundles into three example granaries → inspect the interior |

Each chapter has an introduction, activity, result, and explanation. An upward swipe on a chapter introduction behaves like **Explore**. It never skips unfinished work. Completed chapters offer **Lewati** and direct access to their explanation. Instructions can be tapped and also have a visible **Lanjut** button. Long text scrolls within the current screen; large-text users have explicit buttons for all navigation.

The first visit shows a two-page introduction. Returning home offers resume and a chapter menu with About. Restart asks for confirmation. **Jelajahi ulang** returns home without deleting progress; only **Mulai Ulang** clears it.

## Architecture

MVVM organized by feature. Each folder under `Features/Phases` owns its content, activity, view model, description, and resources. Nukuh owns the imported RealityKit environment. Drying images live in Dibuat. The unused six phase folders, Story Pilot, alternate Harvest home, and standalone 3D overview have been removed.

`JourneyViewModel` owns saved progress. `PhaseSessionState` holds activity outcome. Phase view models validate distinct targets and stage order. `LessonFlowViewModel` handles presentation without granting completion. One motion service is shared by Nukuh, Ngaseuk, and Dibuat. Motion and demonstrations stop when leaving or backgrounding. Nukuh uses relative phone orientation to look around without a camera, automatically calibrating to the current pose when its activity becomes visible. It offers swipe-only and recenter controls; Reduce Motion defaults to swipe-only. Resuming recalibrates while preserving the current view. Ngaseuk and Dibuat motion still require explicit activation. Horizontal drags look around Nukuh; vertical drags scroll its page.

Progress uses `BeBaduy.journey.v2`. Migration leaves v1 data untouched and carries forward only a completed prefix of compatible chapters as previously observed. Dibuat requires both old harvest and drying credit. Migrated users can replay new activities to earn performed credit. Corrupt records are backed up locally. UI tests use a separate defaults suite.

## Verification and content

Tests cover stage gates, distinct targets, motion filtering, progress migration, replay, the complete touch journey, and large text. Simulator tests cannot establish physical-device motion comfort, pinch ergonomics, or device rendering performance.

Existing realistic illustrations remain. Their prompts and current paths are in `realistic-artwork.json`. Some activity controls and 3D vegetation are simplified educational representations. Numbers of trees, holes, and granaries are interface choices, not customary prescriptions. The five chapters are an editorial arrangement; preparation groups multiple farming actions without calling burning itself “Nukuh.”

Research references remain internal in `SourceCatalog.swift`, with no “Baca sumber” links in the learning flow. Angklung music is not bundled pending a suitable recording and reuse permission. Existing virtual fire audio is retained. Small synthesized cues accompany cutting, digging, seed placement, harvesting, bamboo balance, and rain; a sound control is available during activities. These cues are illustrative, not documentary recordings. See [five-chapter adaptation](docs/FIVE_CHAPTER_FLOW.md) for implementation notes. Older planning and verification documents describe historical versions and are not the current feature list.
