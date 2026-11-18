# BeBaduy

Offline SwiftUI learning app for iPhone, iOS 26+. Six chapters introduce rice farming from huma to leuit. No camera, account, server, or third-party packages are required.

## Run

Open `BeBaduy.xcodeproj`, select the **BeBaduy** scheme and an installed iPhone simulator, then Run. Use Xcode 26 or later. Keep the project's existing signing settings when building for a device.

The project uses filesystem-synchronized folders. Add or remove files directly in their feature folders; Xcode discovers them automatically. `scripts/generate_project.py` is legacy scaffolding and must not be run over the current project because it replaces project settings.

## Six-chapter flow

Narawas clears the field, Ngaseuk plants seeds, Ngored removes weeds, Mipit harvests rice, Ngalantai balances and dries the harvest, and Leuit stores it. Instruction and result cards guide learners through the activities.

## Architecture

The app uses feature-first MVVM. Each chapter groups its views, state, rendering and resources under `Features/Chapters`. See [the architecture map](ARCHITECTURE.md) for shared services and tests.

Progress uses `BeBaduy.journey.v2`. Migration leaves v1 data untouched and carries forward only a completed prefix of compatible chapters as previously observed. Mipit requires both old harvest and drying credit. Migrated users can replay new activities to earn performed credit. Corrupt records are backed up locally. UI tests use a separate defaults suite.

## Verification and content

Tests cover stage gates, distinct targets, motion filtering, progress migration, replay, the complete touch journey, and large text. Simulator tests cannot establish physical-device motion comfort, pinch ergonomics, or device rendering performance.

Existing realistic illustrations remain. Their prompts and current paths are in `realistic-artwork.json`. Some activity controls and 3D vegetation are simplified educational representations. Numbers of trees, holes, and granaries are interface choices, not customary prescriptions. The six chapters are an editorial arrangement; preparation groups multiple farming actions without calling burning itself “Narawas.”

Research references remain internal in `SourceCatalog.swift`, with no “Baca sumber” links in the learning flow. Angklung music is not bundled pending a suitable recording and reuse permission. Existing virtual fire audio is retained. Small synthesized cues accompany cutting, digging, seed placement, harvesting, bamboo balance, and rain; a sound control is available during activities. These cues are illustrative, not documentary recordings. See [five-chapter adaptation](docs/FIVE_CHAPTER_FLOW.md) for implementation notes. Older planning and verification documents describe historical versions and are not the current feature list.
