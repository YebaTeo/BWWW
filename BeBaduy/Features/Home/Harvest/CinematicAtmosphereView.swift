//
//  CinematicAtmosphereView.swift
//  PoCPadi
//
//  Renders the warm, immersive sunset aesthetic matching the reference image.
//  Includes environment backdrop, radial sunlight bloom, dusk mist, and floating
//  sunset pollen/dust particles.
//

import SwiftUI

struct CinematicAtmosphereView: View {
    let progress: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var isActive = true
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                // MARK: - 1. Photographic or Procedural Sunset Backdrop
                Group {
                    if UIImage(named: "HumaEnvironment") != nil {
                        Image("HumaEnvironment")
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    } else {
                        // High-fidelity procedural sunset backdrop fallback
                        ProceduralSunsetSkyView()
                    }
                }
                
                // MARK: - 2. Atmospheric Sun Radial Bloom
                // Warm sunset lens glow emanating from behind the mountain ridges (top-trailing)
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.82, blue: 0.50).opacity(0.38),
                        Color(red: 0.98, green: 0.58, blue: 0.28).opacity(0.20),
                        Color.clear
                    ],
                    center: .init(x: 0.78, y: 0.16),
                    startRadius: 20,
                    endRadius: size.width * 0.95
                )
                .blendMode(.screen)
                
                // MARK: - 3. Floating Sunset Dust Particles / Pollen Motes
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isActive || scenePhase != .active)) { timeline in
                    Canvas { context, canvasSize in
                        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        let particleCount = 28
                        
                        for i in 0..<particleCount {
                            let seed = Double(i)
                            let speed = 0.04 + (seed.truncatingRemainder(dividingBy: 5)) * 0.012
                            let progressCycle = (time * speed + seed * 0.15).truncatingRemainder(dividingBy: 1.0)
                            
                            // Calculate position drifting upward and swaying gently
                            let yPos = canvasSize.height * CGFloat(1.0 - progressCycle)
                            let sway = sin(time * 0.8 + seed * 2.0) * 18.0
                            let xPos = (canvasSize.width * CGFloat((seed * 17).truncatingRemainder(dividingBy: 100) / 100.0)) + sway
                            
                            let radius = 1.2 + CGFloat(seed.truncatingRemainder(dividingBy: 3)) * 0.8
                            let opacity = sin(progressCycle * .pi) * 0.65
                            
                            let rect = CGRect(x: xPos - radius, y: yPos - radius, width: radius * 2, height: radius * 2)
                            context.opacity = opacity
                            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 1.0, green: 0.90, blue: 0.65)))
                        }
                    }
                }
                .allowsHitTesting(false)
                
                // MARK: - 4. Foreground Soil Blend Gradient
                // Deepens the ground behind the 3D soil mound so the model blends into the environment
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.40),
                        .init(color: Color(red: 0.12, green: 0.08, blue: 0.05).opacity(0.40), location: 0.60),
                        .init(color: Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.78), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // MARK: - 5. Cinematic Vignette
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.25)
                    ],
                    center: .center,
                    startRadius: size.width * 0.5,
                    endRadius: size.height * 0.85
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Procedural Fallback Sky

/// Renders a warm sunset gradient with atmospheric mountain silhouettes when assets are missing.
private struct ProceduralSunsetSkyView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.22, green: 0.28, blue: 0.38), location: 0.0),
                    .init(color: Color(red: 0.45, green: 0.48, blue: 0.52), location: 0.25),
                    .init(color: Color(red: 0.88, green: 0.65, blue: 0.44), location: 0.48),
                    .init(color: Color(red: 0.96, green: 0.55, blue: 0.28), location: 0.62),
                    .init(color: Color(red: 0.28, green: 0.22, blue: 0.16), location: 0.80),
                    .init(color: Color(red: 0.14, green: 0.10, blue: 0.07), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

