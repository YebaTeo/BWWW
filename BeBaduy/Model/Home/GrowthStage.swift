//
//  GrowthStage.swift
//  PoCPadi
//
//  Represents the distinct cultural & agricultural milestones of traditional
//  Baduy huma rice cultivation (Ngahuma) in the Kanekes hills.
//

import SwiftUI

/// A stage in the BeBaduy huma agricultural journey.
struct GrowthStage: Identifiable, Equatable {
    let id: Int
    let code: String
    let name: String
    let subtitle: String
    let culturalContext: String
    let narrative: String
    let targetProgress: CGFloat // Normalized progress anchor [0.0 ... 1.0]
    let leafColor: Color
    
    /// Formatted step counter (e.g. "01 / 05")
    var stepCounterString: String {
        String(format: "%02d / %02d", id + 1, GrowthStage.allStages.count)
    }
    
    static let allStages: [GrowthStage] = [
        GrowthStage(
            id: 0,
            code: "NUKUH",
            name: "NUKUH",
            subtitle: "Pemilihan & Penyiapan Lahan",
            culturalContext: "Tradisi Awal Ngahuma",
            narrative: "Lahan huma di lereng Kanekes masih dipenuhi semak dan rumput liar. Tetua adat menentukan hari baik untuk membersihkan lahan sebelum benih ditanam.",
            targetProgress: 0.0,
            leafColor: Color(red: 0.52, green: 0.58, blue: 0.28)
        ),
        GrowthStage(
            id: 1,
            code: "NGASEUK",
            name: "NGASEUK",
            subtitle: "Menanam Benih Bersama",
            culturalContext: "Gotong Royong Masyarakat Baduy",
            narrative: "Lahan telah bersih dan subur. Kaum pria membuat lubang tanah dengan tongkat kayu (aseuk), lalu kaum wanita memasukkan butir benih padi huma.",
            targetProgress: 0.333,
            leafColor: Color(red: 0.44, green: 0.76, blue: 0.22)
        ),
        GrowthStage(
            id: 2,
            code: "NGORED",
            name: "NGORED",
            subtitle: "Penyortiran Gulma & Pertumbuhan",
            culturalContext: "Perawatan Tanaman Suci",
            narrative: "Dengan kored (arit kecil), rumput liar disiangi teliti agar tidak mengganggu padi. Rumpun padi huma tumbuh subur dan rimbun menghijau.",
            targetProgress: 0.666,
            leafColor: Color(red: 0.24, green: 0.56, blue: 0.16)
        ),
        GrowthStage(
            id: 3,
            code: "DIBUAT",
            name: "DIBUAT",
            subtitle: "Panen Padi Keemasan",
            culturalContext: "Puncak Rasa Syukur Kanekes",
            narrative: "Bulir padi telah menguning keemasan dan merunduk sarat kemakmuran. Panen dilakukan dengan ketam (ani-ani) sebagai penghormatan kepada Dewi Sri.",
            targetProgress: 0.75,
            leafColor: Color(red: 0.94, green: 0.76, blue: 0.20)
        ),
        GrowthStage(
            id: 4,
            code: "LEUIT",
            name: "LEUIT",
            subtitle: "Menyiapkan Padi untuk Leuit",
            culturalContext: "Ikatan Padi pada Bambu",
            narrative: "Padi hasil panen digantung pada rak bambu.",
            targetProgress: 1.0,
            leafColor: Color(red: 0.85, green: 0.62, blue: 0.24)
        )
    ]
    
    /// Finds the closest matching stage given a normalized progress value [0.0 ... 1.0].
    static func currentStage(for progress: CGFloat) -> GrowthStage {
        let clamped = min(1.0, max(0.0, progress))
        // The anchors are intentionally non-uniform: the first four stages
        // occupy the farming timeline, while the final quarter is reserved
        // for the pan to the leuit. Resolve against the actual anchors so the
        // HUD changes at the same moments as the SceneKit scene.
        return allStages.min {
            abs($0.targetProgress - clamped) < abs($1.targetProgress - clamped)
        } ?? allStages[0]
    }
}

