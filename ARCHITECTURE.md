# BeBaduy project organization

| Folder under BeBaduy | Responsibility |
| --- | --- |
| App | Entry point, dependency assembly, launch and app resources |
| Features/Home, Onboarding, Journey | Home experience, first-use stories, chapter navigation and progress |
| Features/Chapters | Narawas, Ngaseuk, Ngored, Mipit, Ngalantai and NgaleuitkeunPare. Each groups its views, view models, rendering, services and resources as needed. |
| Features/Completion, Collection, About | Ending and Leuit discovery, collected cards, educational sources |
| Shared/Learning | Phase content, stable identifiers, landscape and session models |
| Shared/ActivityUI and DesignSystem | Common activity layout, cards, controls, buttons and theme |
| Shared/Rendering | Huma renderer, shared materials, effects, geometry and scenery assets |
| Shared/Services | Motion, orientation, audio and persistence |

Chapter view models own activity rules. Journey owns progress and navigation. Renderers own visual state. Unit tests mirror their owners under BeBaduyTests. BeBaduyUITests covers whole journeys. Xcode discovers source and resources through the three synchronized target roots.
