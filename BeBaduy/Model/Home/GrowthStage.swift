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
    let phase: PhaseID
    let code: String
    let name: String
    let subtitle: String
    let culturalContext: String
    let narrative: String
    let targetProgress: CGFloat // Normalized progress anchor [0.0 ... 1.0]
    let leafColor: Color
    
    var isConclusion: Bool { id == 6 }

    /// Formatted step counter (e.g. "01 / 05")
    var stepCounterString: String {
        String(format: "%02d / %02d", id + 1, GrowthStage.allStages.count)
    }
    
    static let allStages: [GrowthStage] = [
        GrowthStage(
            id: 0,
            phase: .narawas,
            code: "NARAWAS",
            name: "NARAWAS",
            subtitle: "Pemilihan & Penyiapan Lahan",
            culturalContext: "Tradisi Awal Ngahuma",
            narrative: PhaseContent.content(for: .narawas).introduction,
            targetProgress: 0.0,
            leafColor: Color(red: 0.52, green: 0.58, blue: 0.28)
        ),
        GrowthStage(
            id: 1,
            phase: .ngaseuk,
            code: "NGASEUK",
            name: "NGASEUK",
            subtitle: "Menanam Benih Bersama",
            culturalContext: "Gotong Royong Masyarakat Baduy",
            narrative: PhaseContent.content(for: .ngaseuk).introduction,
            targetProgress: 0.333,
            leafColor: Color(red: 0.44, green: 0.76, blue: 0.22)
        ),
        GrowthStage(
            id: 2,
            phase: .ngored,
            code: "NGORED",
            name: "NGORED",
            subtitle: "Penyortiran Gulma & Pertumbuhan",
            culturalContext: "Perawatan Tanaman Suci",
            narrative: PhaseContent.content(for: .ngored).introduction,
            targetProgress: 0.666,
            leafColor: Color(red: 0.24, green: 0.56, blue: 0.16)
        ),
        GrowthStage(
            id: 3,
            phase: .mipit,
            code: "MIPIT",
            name: "MIPIT",
            subtitle: "Panen Padi Keemasan",
            culturalContext: "Puncak Rasa Syukur Kanekes",
            narrative: PhaseContent.content(for: .mipit).introduction,
            targetProgress: 0.75,
            leafColor: Color(red: 0.94, green: 0.76, blue: 0.20)
        ),
        GrowthStage(
            id: 4,
            phase: .ngalantai,
            code: "NGALANTAI",
            name: "NGALANTAI",
            subtitle: "Mengeringkan padi",
            culturalContext: "Menyiapkan hasil panen",
            narrative: PhaseContent.content(for: .ngalantai).introduction,
            targetProgress: 0.90,
            leafColor: Color(red: 0.85, green: 0.62, blue: 0.24)
        ),
        GrowthStage(
            id: 5,
            phase: .ngaleuitkeunPare,
            code: "LEUIT",
            name: "NGALEUITKEUN",
            subtitle: "Menyimpan hasil panen",
            culturalContext: "Lumbung padi",
            narrative: PhaseContent.content(for: .ngaleuitkeunPare).introduction,
            targetProgress: 0.95,
            leafColor: Color(red: 0.85, green: 0.62, blue: 0.24)
        ),
        GrowthStage(
            id: 6,
            phase: .ngaleuitkeunPare,
            code: "MENGELOLA PARE HUMA",
            name: "MENGELOLA PARE HUMA",
            subtitle: "Menjaga hasil perjalanan",
            culturalContext: "Dari huma ke leuit",
            narrative: "Dari menyiapkan huma hingga menyimpan padi di leuit, setiap tahap mengajarkan cara merawat pangan dan kehidupan bersama.",
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


/// Shared camera and landscape timing for the Leuit → conclusion sweep.
enum HomeConclusionPan {
    static let distance: Float = 2.4

    static func amount(progress: CGFloat) -> CGFloat {
        let x = min(1, max(0, (progress - 0.95) / 0.05))
        // Strong ease-in-out: cubic-bezier(0.77, 0, 0.175, 1).
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        for _ in 0..<16 {
            let t = (lower + upper) / 2
            let inverse = 1 - t
            let curveX = 3 * inverse * inverse * t * 0.77 + 3 * inverse * t * t * 0.175 + t * t * t
            if curveX < x { lower = t } else { upper = t }
        }
        let t = (lower + upper) / 2
        return x == 0 ? 0 : (x == 1 ? 1 : t * t * (3 - 2 * t))
    }
}
