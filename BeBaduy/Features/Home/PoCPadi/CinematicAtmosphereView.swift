//
//  CinematicAtmosphereView.swift
//  PoCPadi
//
//  A layered photographic environment whose depth and light follow the
//  farming preview timeline.
//

import SwiftUI

struct CinematicAtmosphereView: View {
    let progress: CGFloat
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var orbitPhase: Double {
        let t = min(1, max(0, (progress - 0.666) / (0.75 - 0.666)))
        // Ten half-orbits make five complete day/night cycles and return to
        // the same morning light at the Dibuat endpoint.
        return Double(t) * .pi * 10
    }

    private var daylight: CGFloat {
        // Ngored (.666) begins in morning. During the Ngored → Dibuat
        // transition the light completes five day/night cycles, beginning and
        // ending in daylight on Dibuat.
        return CGFloat((1 - cos(orbitPhase)) / 2)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let depth = CGFloat(progress - 0.5)
            let night = daylight
            // Keep the orbit low so the sun follows the ridge line instead
            // of crossing the open sky; the moon uses the opposite arc.
            let orbitX = size.width * 0.43
            let orbitY = size.height * 0.055
            let horizon = size.height * 0.25
            let sun = CGPoint(x: size.width * 0.5 + orbitX * sin(orbitPhase),
                              y: horizon - orbitY * cos(orbitPhase))
            let moon = CGPoint(x: size.width * 0.5 - orbitX * sin(orbitPhase),
                               y: horizon + orbitY * cos(orbitPhase))
            let sunVisibility = min(1, max(0, cos(orbitPhase) * 5))
            let moonVisibility = min(1, max(0, -cos(orbitPhase) * 5))
            let imageAvailable = UIImage(named: "HumaEnvironment") != nil

            ZStack {
                // Sky is a separate clean region of the source photograph.
                if let sky = Self.skyImage {
                    Image(uiImage: sky).resizable().scaledToFill()
                        .frame(width: size.width, height: size.height).clipped()
                        .scaleEffect(1.04)
                        .offset(x: -depth * 4)
                } else {
                    ProceduralSunsetSkyView()
                }

                // Daylight glow changes hue and position as the sun crosses
                // the sky. It fades away in the night portions of the cycle.
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.34 * (1 - night)),
                        Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.16 * (1 - night)),
                        .clear
                    ],
                    center: UnitPoint(x: sun.x / max(1, size.width), y: sun.y / max(1, size.height)),
                    startRadius: 8,
                    endRadius: size.width * 0.78
                )
                .blendMode(.screen)

                // A cool blue veil signals night and returns to clear dawn.
                Color(red: 0.018, green: 0.030, blue: 0.075)
                    .opacity(0.88 * night)

                RadialGradient(
                    colors: [Color(red: 0.32, green: 0.48, blue: 0.82).opacity(0.10 * night), .clear],
                    center: UnitPoint(x: moon.x / max(1, size.width), y: moon.y / max(1, size.height)),
                    startRadius: 10,
                    endRadius: size.width * 0.58
                )
                .blendMode(.screen)

                // Celestial cues make night recognizable beyond dimming the photo.
                Canvas { context, canvasSize in
                    for index in 0..<48 {
                        let seed = Double(index)
                        let x = canvasSize.width * CGFloat((seed * 0.6180339 + 0.13).truncatingRemainder(dividingBy: 1))
                        let y = canvasSize.height * CGFloat(0.025 + (seed * 0.381966).truncatingRemainder(dividingBy: 1) * 0.26)
                        let radius: CGFloat = index % 7 == 0 ? 0.9 : 0.45
                        context.opacity = index % 3 == 0 ? 0.48 : 0.24
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(.white))
                    }
                }
                .opacity(night * night)

                // Opposite bodies share one circular orbit. The lower half
                // is hidden beneath the landscape horizon.
                celestialBody(isMoon: false)
                    .position(sun)
                    .opacity(sunVisibility)
                celestialBody(isMoon: true)
                    .position(moon)
                    .opacity(moonVisibility)

                if imageAvailable {
                    // Back-to-front opaque cutouts occlude celestial objects.
                    landscapeLayer(size: size, contour: Self.ridge, night: night)
                        .offset(x: depth * 5)
                    landscapeLayer(size: size, contour: Self.grass, night: night)
                        .offset(x: depth * 10)
                    landscapeLayer(size: size, contour: Self.soil, night: night)
                        .offset(x: depth * 16)
                }

                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isActive || scenePhase != .active)) { timeline in
                    Canvas { context, canvasSize in
                        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        for i in 0..<28 {
                            let seed = Double(i)
                            let speed = 0.04 + (seed.truncatingRemainder(dividingBy: 5)) * 0.012
                            let cycle = (time * speed + seed * 0.15).truncatingRemainder(dividingBy: 1.0)
                            let y = canvasSize.height * CGFloat(1 - cycle)
                            let x = canvasSize.width * CGFloat((seed * 17).truncatingRemainder(dividingBy: 100) / 100) + sin(time * 0.8 + seed * 2) * 18
                            let radius = 1.2 + CGFloat(i % 3) * 0.8
                            let opacity = sin(cycle * .pi) * (0.65 - 0.42 * night)
                            context.opacity = opacity
                            context.fill(
                                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                with: .color(Color(red: 1, green: 0.90, blue: 0.65))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.40),
                        .init(color: Color(red: 0.12, green: 0.08, blue: 0.05).opacity(0.40), location: 0.60),
                        .init(color: Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.78), location: 1)
                    ], startPoint: .top, endPoint: .bottom
                )

                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.25 + 0.14 * night)],
                    center: .center,
                    startRadius: size.width * 0.5,
                    endRadius: size.height * 0.85
                )
            }
        }
        .clipped()
        .ignoresSafeArea()
    }

    private func celestialBody(isMoon: Bool) -> some View {
        let diameter: CGFloat = isMoon ? 22 : 27
        return ZStack {
            // Atmospheric scattering fades gradually rather than forming a
            // bright ring around either disk.
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color.white.opacity(isMoon ? 0.055 : 0.34), location: 0),
                    .init(color: (isMoon ? Color.blue : Color(red: 1, green: 0.88, blue: 0.70)).opacity(isMoon ? 0.015 : 0.10), location: 0.4),
                    .init(color: .clear, location: 1)
                ], center: .center, startRadius: 0, endRadius: 65))
                .frame(width: 90, height: 90)
            if isMoon {
                ZStack {
                    Circle().fill(RadialGradient(
                        colors: [Color(red: 0.94, green: 0.93, blue: 0.87), Color(red: 0.57, green: 0.62, blue: 0.69)],
                        center: .topLeading, startRadius: 1, endRadius: diameter))
                    Canvas { context, size in
                        // Fixed irregular mare patches and small crater rims.
                        // Deterministic coordinates avoid texture flicker.
                        for i in 0..<42 {
                            let seed = Double(i)
                            let x = (sin(seed * 12.9898 + 1) * 43758.5453).truncatingRemainder(dividingBy: 1)
                            let y = (sin(seed * 7.233 + 4) * 23421.631).truncatingRemainder(dividingBy: 1)
                            let radius = CGFloat(i % 6 == 0 ? 2.5 : 0.4 + Double(i % 4) * 0.25)
                            let rect = CGRect(x: abs(x) * size.width, y: abs(y) * size.height,
                                              width: radius * 1.6, height: radius)
                            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.28, green: 0.32, blue: 0.36).opacity(i % 6 == 0 ? 0.16 : 0.09)))
                            if i % 6 != 0 {
                                context.stroke(Path(ellipseIn: rect.offsetBy(dx: -0.2, dy: -0.3)),
                                               with: .color(.white.opacity(0.08)), lineWidth: 0.25)
                            }
                        }
                    }
                    .blur(radius: 0.25)
                    // Soft terminator suggests a nearly full illuminated sphere.
                    Circle()
                        .fill(Color(red: 0.025, green: 0.04, blue: 0.08).opacity(0.52))
                        .offset(x: diameter * 0.64, y: diameter * 0.12)
                        .blur(radius: 1.4)
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: Color.white, location: 0),
                        .init(color: Color(red: 1, green: 0.99, blue: 0.96), location: 0.76),
                        .init(color: Color(red: 1, green: 0.91, blue: 0.78), location: 1)
                    ], center: .center, startRadius: 0, endRadius: diameter / 2))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: Color.white.opacity(0.55), radius: 7)
                    .shadow(color: Color(red: 1, green: 0.88, blue: 0.70).opacity(0.35), radius: 14)
                    .blur(radius: 0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Contours use the 1024 × 1536 source coordinate space, so the mask
    // and photograph remain aligned under aspect-fill on every screen size.
    private static let ridge: [CGPoint] = [
        .init(x: 0, y: 382), .init(x: 80, y: 357), .init(x: 145, y: 342),
        .init(x: 190, y: 349), .init(x: 275, y: 388), .init(x: 345, y: 398),
        .init(x: 440, y: 389), .init(x: 550, y: 395), .init(x: 640, y: 371),
        .init(x: 710, y: 343), .init(x: 770, y: 333), .init(x: 820, y: 350),
        .init(x: 885, y: 336), .init(x: 950, y: 350), .init(x: 1024, y: 370)
    ]
    private static let grass: [CGPoint] = [
        .init(x: 0, y: 555), .init(x: 100, y: 565), .init(x: 200, y: 588),
        .init(x: 330, y: 605), .init(x: 440, y: 616), .init(x: 570, y: 598),
        .init(x: 700, y: 570), .init(x: 850, y: 550), .init(x: 1024, y: 548)
    ]
    private static let soil: [CGPoint] = [
        .init(x: 0, y: 672), .init(x: 150, y: 645), .init(x: 300, y: 634),
        .init(x: 440, y: 634), .init(x: 600, y: 625), .init(x: 780, y: 607),
        .init(x: 1024, y: 596)
    ]
    private static let skyImage: UIImage? = {
        guard let source = UIImage(named: "HumaEnvironment")?.cgImage,
              let crop = source.cropping(to: CGRect(x: 350, y: 0, width: 540, height: 320)) else { return nil }
        return UIImage(cgImage: crop)
    }()

    private func landscapeLayer(size: CGSize, contour: [CGPoint], night: CGFloat) -> some View {
        let scale = max(size.width / 1024, size.height / 1536) * 1.04
        let width = 1024 * scale
        let height = 1536 * scale
        return Image("HumaEnvironment")
            .resizable()
            .frame(width: width, height: height)
            .overlay(Color(red: 0.018, green: 0.030, blue: 0.075).opacity(0.88 * night))
            .mask {
                Path { path in
                    guard let first = contour.first else { return }
                    path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
                    for point in contour.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
    }

}

private struct ProceduralSunsetSkyView: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.22, green: 0.28, blue: 0.38), location: 0),
                .init(color: Color(red: 0.45, green: 0.48, blue: 0.52), location: 0.25),
                .init(color: Color(red: 0.88, green: 0.65, blue: 0.44), location: 0.48),
                .init(color: Color(red: 0.96, green: 0.55, blue: 0.28), location: 0.62),
                .init(color: Color(red: 0.28, green: 0.22, blue: 0.16), location: 0.80),
                .init(color: Color(red: 0.14, green: 0.10, blue: 0.07), location: 1)
            ], startPoint: .top, endPoint: .bottom
        )
    }
}
