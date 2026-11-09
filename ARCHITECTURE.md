# Project organization

The application has four main folders:

| Folder | Purpose |
| --- | --- |
| `View` | SwiftUI screens, reusable components, theme, native view adapters and app entry point |
| `Model` | Domain data, content catalogs, stage definitions and `ViewModels` for observable presentation state |
| `Services` | SceneKit renderers, motion, audio, persistence and dependency composition |
| `Asset` | Asset catalogs, textures, images, audio and other bundled resources |

Subfolders group related files by feature. Shared code lives in `Model/Shared`, `Services/Shared`, and `View/Components`.

Views render state and forward user actions. View models own presentation logic and orchestrate services. Models describe data and domain state. Services implement rendering and device or persistence operations.

Home preview selection and playback belong to `Model/ViewModels/Home/HomePreviewViewModel.swift`. Its SceneKit graph and effects belong to `Services/Home/HomeSceneRenderer.swift`. `View/Home/SceneKitCropView.swift` is the native view adapter.

Nukuh uses `Model/ViewModels/Nukuh/NukuhViewModel.swift` for activity orchestration and `Services/Nukuh/NgahumaScene.swift` for rendering. Shared material factories live in `Services/Shared/Rendering`.

Asset names remain stable, so asset lookups use the same names. Xcode's filesystem-synchronized app group automatically includes these folders.
