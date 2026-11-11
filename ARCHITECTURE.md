# Project organization

| Folder | Responsibility |
| --- | --- |
| `View/Home` | Animated five-stage preview and chapter navigation |
| `View/Gameplay` | Full-screen activities, native view adapters, and instruction sheets grouped by chapter |
| `View/Info` | Chapter explanations. The shared chapter container displays introductions from chapter content |
| `Model` | Chapter content, stable phase identifiers, saved progress, and ViewModels |
| `Services/Rendering` | Home and Narawas SceneKit renderers and shared geometry, material, and particle builders |
| `Services/Motion`, `Audio`, and `Persistence` | Device motion, activity sound, and saved progress |
| `Asset` | Bundled images, textures, and audio grouped by feature |

Home preview selection is independent of saved completion. Gameplay ViewModels validate interactions and handle demonstrations. Narawas's renderer reports tree and land taps, readiness, and settled fires. The ViewModel decides which actions are valid and when the activity completes. The renderer owns the camera pose, SceneKit objects, and per-patch visual timing.

The shared chapter container handles introduction, optional equipment, activity, result, and explanation. The activity is the only screen that presents its instruction sheet.

Xcode discovers app files through its filesystem-synchronized folder. Keep persisted phase identifiers and asset lookup keys stable when moving files. The older plans under `docs` document earlier iterations. README and this file describe the current implementation.
