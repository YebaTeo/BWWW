from pathlib import Path
root=Path(__file__).resolve().parent.parent
folders=['Narawas','Nyacar','Ngaganggang','Ngahuru','Ngored','NgubaranPare','Dibuat','DryingRice','Ngunjal','NgaleuitkeunPare']
for folder in folders:
 d=root/'BeBaduy/Features/Phases'/folder
 (d/f'{folder}View.swift').write_text(f'''import SwiftUI
struct {folder}View: View {{
    let journey: JourneyViewModel
    let advance: () -> Void
    @State private var model = {folder}ViewModel()
    var body: some View {{
        PhaseContainerView(content: {folder}Content.value, session: model.session, journey: journey,
            start: model.start, replay: model.start, demonstrate: model.demonstrate,
            restore: {{ model.session.restore($0) }}, advance: advance,
            introduction: {{ {folder}IntroductionView() }}, activity: {{ {folder}ActivityView(model: model) }},
            description: {{ {folder}DescriptionView() }})
    }}
}}
''')
