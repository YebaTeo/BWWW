# BeBaduy project instructions

Read docs/IMPLEMENTATION_PLAN.md and docs/CODEX_BUILD_PROMPT.md before changing app behavior.

- Native SwiftUI, iOS 26+, Observation MVVM. Keep every phase's views, model, content, and resources together under Features/Phases.
- JourneyViewModel owns durable progress. Phase view models own short-lived activity rules. Replay must never erase durable completion.
- Activity completion, description availability, and continuing are distinct events. Keep explanations in the vertical phase page; no automatic scroll or navigation on success.
- Preserve touch/select equivalents and explicit demonstrations. Motion is optional and must stop on exit, inactivity, mode change, or completion.
- Keep cultural claims tied to SourceCatalog. Do not present prototype quantities or diagram placement as customary practice.
- Research references are internal development metadata. Do not display source IDs, bibliography links, "Baca sumber", or a public sources screen. The product should build curiosity about Baduy and encourage a respectful future visit.
- Run `python3 scripts/generate_project.py` after adding/removing Swift files or asset catalogs. The checked-in project needs no third-party generator.
- Use the Xcode path and simulator instructions in README.md; update docs/VERIFICATION.md with checks actually run. Do not claim physical-device, VoiceOver, or cultural review that was not performed.
