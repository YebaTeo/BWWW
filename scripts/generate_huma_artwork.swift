import Foundation
import CoreGraphics
import ImageIO
import Accelerate

// MARK: - Core Utilities

func loadCGImage(at path: String) -> CGImage? {
    guard let provider = CGDataProvider(filename: path) else {
        print("Failed to load provider at \(path)")
        return nil
    }
    return CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
}

func savePNG(image: CGImage, to path: String) {
    let original = URL(fileURLWithPath: path)
    let name = original.deletingPathExtension().lastPathComponent
    let requested = CommandLine.arguments.dropFirst()
    guard requested.isEmpty || requested.contains(name) else { return }
    let url = ProcessInfo.processInfo.environment["HUMA_ARTWORK_OUTPUT"]
        .map { URL(fileURLWithPath: $0, isDirectory: true).appendingPathComponent(original.lastPathComponent) }
        ?? original
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("Failed to create CGImageDestination for \(path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Failed to finalize PNG at \(path)")
    }
    print("Successfully generated and saved: \(path)")
}

func createBitmapContext(width: Int, height: Int) -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fatalError("Failed to create CGContext \(width)x\(height)")
    }
    context.interpolationQuality = .high
    return context
}

// Convert top-left (UIKit-style) rect to CoreGraphics (bottom-left) rect
func cgRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, contextHeight: CGFloat) -> CGRect {
    return CGRect(x: x, y: contextHeight - y - height, width: width, height: height)
}

// Draw image using top-left coordinates
func drawImage(in context: CGContext, image: CGImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, contextHeight: CGFloat, blendMode: CGBlendMode = .normal, alpha: CGFloat = 1.0) {
    context.saveGState()
    context.setBlendMode(blendMode)
    context.setAlpha(alpha)
    let rect = cgRect(x: x, y: y, width: width, height: height, contextHeight: contextHeight)
    context.draw(image, in: rect)
    context.restoreGState()
}

// Tile an image across a region
func tileImage(in context: CGContext, image: CGImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, tileSize: CGFloat, contextHeight: CGFloat, blendMode: CGBlendMode = .normal, alpha: CGFloat = 1.0) {
    context.saveGState()
    context.setBlendMode(blendMode)
    context.setAlpha(alpha)
    let clipRect = cgRect(x: x, y: y, width: width, height: height, contextHeight: contextHeight)
    context.clip(to: clipRect)
    
    var curY = y
    while curY < y + height {
        var curX = x
        while curX < x + width {
            let tileRect = cgRect(x: curX, y: curY, width: tileSize, height: tileSize, contextHeight: contextHeight)
            context.draw(image, in: tileRect)
            curX += tileSize
        }
        curY += tileSize
    }
    context.restoreGState()
}

// Add a soft vertical gradient
func drawVerticalGradient(in context: CGContext, topColor: (CGFloat, CGFloat, CGFloat, CGFloat), bottomColor: (CGFloat, CGFloat, CGFloat, CGFloat), rect: CGRect, contextHeight: CGFloat) {
    context.saveGState()
    let cgR = cgRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height, contextHeight: contextHeight)
    context.clip(to: cgR)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(colorSpace: colorSpace, components: [topColor.0, topColor.1, topColor.2, topColor.3])!,
        CGColor(colorSpace: colorSpace, components: [bottomColor.0, bottomColor.1, bottomColor.2, bottomColor.3])!
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    context.drawLinearGradient(gradient, start: CGPoint(x: cgR.midX, y: cgR.maxY), end: CGPoint(x: cgR.midX, y: cgR.minY), options: [])
    context.restoreGState()
}

// MARK: - Assets Loading

let W = 1024
let H = 1536
let fW = CGFloat(W)
let fH = CGFloat(H)

print("Loading reference textures...")
guard let humaEnv = loadCGImage(at: "BeBaduy/Asset/Home/PoCPadi.xcassets/HumaEnvironment.imageset/huma-environment.png"),
      let terrainTex = loadCGImage(at: "BeBaduy/Asset/Home/PoCPadi.xcassets/HumaTerrainTexture.imageset/terrain.png"),
      let youngRiceTex = loadCGImage(at: "BeBaduy/Asset/Home/PoCPadi.xcassets/HumaYoungRice.imageset/huma-young-rice.png"),
      let naturalTreeTex = loadCGImage(at: "BeBaduy/Asset/Home/PoCPadi.xcassets/HumaTreeNatural.imageset/tree-natural.png"),
      let woodTex = loadCGImage(at: "BeBaduy/Asset/Home/PoCPadi.xcassets/HumaWoodTexture.imageset/texture.png"),
      let thatchTex = loadCGImage(at: "BeBaduy/Asset/Home/PoCPadi.xcassets/HumaThatchTexture.imageset/texture.png"),
      let ashTex = loadCGImage(at: "BeBaduy/Asset/Narawas/ngahuma-ash.png") else {
    fatalError("Failed to load required source textures!")
}

print("All reference textures loaded.")

// MARK: - Specialized Drawing Helpers

/// Draws the shared HumaEnvironment base (sky, distant mountain silhouettes, tree line, horizon grass)
func drawHumaBase(in ctx: CGContext, skyShift: CGFloat = 0, soilBlend: CGFloat = 0.35) {
    // 1. Draw HumaEnvironment
    drawImage(in: ctx, image: humaEnv, x: 0, y: 0, width: fW, height: fH, contextHeight: fH)
    
    // 2. Enhance the soil region (y: 650 to 1536) with HumaTerrainTexture for crisp authentic Baduy earth clods & pebbles
    if soilBlend > 0 {
        ctx.saveGState()
        // Clip to soil region with soft feather along horizon
        let soilTop: CGFloat = 630.0
        let soilRect = cgRect(x: 0, y: soilTop, width: fW, height: fH - soilTop, contextHeight: fH)
        ctx.clip(to: soilRect)
        
        // Tile terrain texture with soft overlay/softLight mode
        tileImage(in: ctx, image: terrainTex, x: 0, y: soilTop, width: fW, height: fH - soilTop, tileSize: 512, contextHeight: fH, blendMode: .overlay, alpha: soilBlend)
        ctx.restoreGState()
    }
}

/// Draws golden unhulled rice grains (individual seeds)
func drawRiceGrains(in ctx: CGContext, center: CGPoint, count: Int, radius: CGFloat) {
    ctx.saveGState()
    let goldLight = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.96, 0.84, 0.52, 1.0])!
    let goldDark = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.65, 0.48, 0.22, 1.0])!
    
    for i in 0..<count {
        let angle = Double(i) * 2.39996 + Double(center.x) // Golden angle offset
        let r = radius * CGFloat(sqrt(Double(i + 1) / Double(count)))
        let gx = center.x + r * CGFloat(cos(angle))
        let gy = center.y + r * CGFloat(sin(angle)) * 0.6 // Foreshortened
        
        let grainW: CGFloat = 9.0
        let grainH: CGFloat = 4.5
        let grainRect = cgRect(x: gx - grainW/2, y: gy - grainH/2, width: grainW, height: grainH, contextHeight: fH)
        
        ctx.saveGState()
        ctx.translateBy(x: grainRect.midX, y: grainRect.midY)
        ctx.rotate(by: CGFloat(angle))
        let localRect = CGRect(x: -grainW/2, y: -grainH/2, width: grainW, height: grainH)
        
        ctx.setFillColor(goldDark)
        ctx.fillEllipse(in: localRect)
        ctx.setFillColor(goldLight)
        ctx.fillEllipse(in: localRect.insetBy(dx: 1, dy: 1))
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

/// Draws an authentic dibble planting hole in the warm soil
func drawDibbleHole(in ctx: CGContext, center: CGPoint, width: CGFloat, height: CGFloat, withSeeds: Bool) {
    ctx.saveGState()
    let holeRect = cgRect(x: center.x - width/2, y: center.y - height/2, width: width, height: height, contextHeight: fH)
    
    // 1. Loose soil excavated rim (slightly elevated, warm clods)
    let rimRect = holeRect.insetBy(dx: -8, dy: -5)
    ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.44, 0.28, 0.16, 0.5])!)
    ctx.fillEllipse(in: rimRect)
    
    // 2. Hole depression (deep dark fertile shadow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let holeGradColors = [
        CGColor(colorSpace: colorSpace, components: [0.08, 0.04, 0.02, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.28, 0.17, 0.10, 1.0])!
    ] as CFArray
    let holeGrad = CGGradient(colorsSpace: colorSpace, colors: holeGradColors, locations: [0.0, 1.0])!
    ctx.saveGState()
    ctx.addEllipse(in: holeRect)
    ctx.clip()
    ctx.drawRadialGradient(holeGrad, startCenter: CGPoint(x: holeRect.midX, y: holeRect.midY), startRadius: 0, endCenter: CGPoint(x: holeRect.midX, y: holeRect.midY), endRadius: width/2, options: [])
    ctx.restoreGState()
    
    // 3. Rim contour shadow
    ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.20, 0.12, 0.07, 0.8])!)
    ctx.setLineWidth(1.5)
    ctx.strokeEllipse(in: holeRect)
    
    // 4. Rice seeds inside if seeded
    if withSeeds {
        drawRiceGrains(in: ctx, center: center, count: 4, radius: width * 0.22)
    }
    ctx.restoreGState()
}

/// Draws a natural ripe golden rice panicle arching over
func drawRipePanicle(in ctx: CGContext, origin: CGPoint, bendDirection: CGFloat, scale: CGFloat = 1.0) {
    ctx.saveGState()
    let stemColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.72, 0.62, 0.32, 1.0])!
    let goldGrain = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.94, 0.82, 0.44, 1.0])!
    let goldShadow = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.58, 0.42, 0.18, 1.0])!
    
    // 1. Draw curving stem
    ctx.setStrokeColor(stemColor)
    ctx.setLineWidth(2.5 * scale)
    ctx.setLineCap(.round)
    
    let path = CGMutablePath()
    let startP = CGPoint(x: origin.x, y: fH - origin.y)
    let endP = CGPoint(x: origin.x + 95 * bendDirection * scale, y: fH - (origin.y + 130 * scale))
    let ctrlP = CGPoint(x: origin.x + 40 * bendDirection * scale, y: fH - (origin.y + 40 * scale))
    path.move(to: startP)
    path.addQuadCurve(to: endP, control: ctrlP)
    ctx.addPath(path)
    ctx.strokePath()
    
    // 2. Draw attached drooping grains along the curve
    for step in 0..<18 {
        let t = CGFloat(step) / 17.0
        let mt = 1.0 - t
        // Bezier formula
        let gx = mt * mt * startP.x + 2 * mt * t * ctrlP.x + t * t * endP.x
        let gy = mt * mt * startP.y + 2 * mt * t * ctrlP.y + t * t * endP.y
        
        let spread: CGFloat = (step > 6 ? 14.0 : 6.0) * scale
        let grainOffsetX = (step % 2 == 0 ? spread : -spread * 0.7) * (0.5 + t * 0.5)
        let grainOffsetY = CGFloat((step % 3) - 1) * 3.0 * scale
        
        let gRect = CGRect(x: gx + grainOffsetX - 6 * scale, y: gy + grainOffsetY - 3 * scale, width: 12 * scale, height: 6 * scale)
        ctx.saveGState()
        ctx.translateBy(x: gRect.midX, y: gRect.midY)
        ctx.rotate(by: CGFloat(t * 0.8 * bendDirection))
        let localR = CGRect(x: -6 * scale, y: -3 * scale, width: 12 * scale, height: 6 * scale)
        ctx.setFillColor(goldShadow)
        ctx.fillEllipse(in: localR)
        ctx.setFillColor(goldGrain)
        ctx.fillEllipse(in: localR.insetBy(dx: 1 * scale, dy: 1 * scale))
        ctx.restoreGState()
    }
    
    ctx.restoreGState()
}

/// Draws an authentic Baduy harvested rice bundle (poc padi)
func drawRiceBundle(in ctx: CGContext, center: CGPoint, width: CGFloat, height: CGFloat) {
    ctx.saveGState()
    let neck = center.y - height * 0.22
    let colors: [[CGFloat]] = [
        [0.67, 0.46, 0.19, 1], [0.83, 0.61, 0.25, 1], [0.96, 0.76, 0.38, 1]
    ]
    func color(_ index: Int) -> CGColor {
        CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: colors[index % colors.count])!
    }

    for strand in 0..<13 {
        let spread = CGFloat(strand - 6) / 6
        let end = center.y + height * (0.47 - abs(spread) * 0.18)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x + spread * width * 0.23, y: fH - (neck - height * 0.24)))
        path.addQuadCurve(
            to: CGPoint(x: center.x + spread * width * 0.42, y: fH - end),
            control: CGPoint(x: center.x + spread * width * 0.06, y: fH - neck)
        )
        ctx.setStrokeColor(color(strand))
        ctx.setLineWidth(max(1, width * 0.025))
        ctx.addPath(path)
        ctx.strokePath()
        for row in 0..<8 {
            let fraction = CGFloat(row) / 8
            let y = neck + (end - neck) * (0.30 + 0.70 * fraction)
            let x = center.x + spread * width * (0.15 + fraction * 0.27)
            ctx.setFillColor(color(strand + row))
            ctx.fillEllipse(in: cgRect(x: x - width * 0.034, y: y,
                                       width: width * 0.068, height: height * 0.075,
                                       contextHeight: fH))
        }
    }
    for binding in 0..<3 {
        ctx.setStrokeColor(color(binding))
        ctx.setLineWidth(max(1, height * 0.018))
        let y = fH - neck - CGFloat(binding) * height * 0.019
        ctx.move(to: CGPoint(x: center.x - width * 0.13, y: y))
        ctx.addLine(to: CGPoint(x: center.x + width * 0.13, y: y))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

// MARK: - 1. Narawas Before (ngahuru_before)
print("Rendering ngahuru_before...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.25)
    
    // Standing wild trees across the huma at forest edge
    // Tree 1: Left midground
    drawImage(in: ctx, image: naturalTreeTex, x: 20, y: 380, width: 340, height: 480, contextHeight: fH)
    // Tree 2: Far left background
    drawImage(in: ctx, image: naturalTreeTex, x: -80, y: 310, width: 280, height: 400, contextHeight: fH, alpha: 0.85)
    // Tree 3: Center-left
    drawImage(in: ctx, image: naturalTreeTex, x: 260, y: 390, width: 320, height: 460, contextHeight: fH)
    // Tree 4: Center-right
    drawImage(in: ctx, image: naturalTreeTex, x: 480, y: 400, width: 350, height: 490, contextHeight: fH)
    // Tree 5: Right background
    drawImage(in: ctx, image: naturalTreeTex, x: 740, y: 340, width: 300, height: 420, contextHeight: fH, alpha: 0.88)
    // Tree 6: Right foreground
    drawImage(in: ctx, image: naturalTreeTex, x: 680, y: 420, width: 380, height: 530, contextHeight: fH)
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Narawas/Ngahuru.xcassets/ngahuru_before.imageset/ngahuru_before.png")
}

// MARK: - 2. Narawas After (ngahuru_after)
print("Rendering ngahuru_after...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.3)
    
    // Overlay charred ash & soot patches from the 6 fires cooling down into fertile soil
    let ashY: CGFloat = 650
    tileImage(in: ctx, image: ashTex, x: 0, y: ashY, width: fW, height: fH - ashY, tileSize: 620, contextHeight: fH, blendMode: .multiply, alpha: 0.55)
    
    // Add warm sunlit glow over the cleared soil
    drawVerticalGradient(
        in: ctx,
        topColor: (1.0, 0.95, 0.85, 0.10),
        bottomColor: (0.15, 0.10, 0.05, 0.25),
        rect: CGRect(x: 0, y: ashY, width: fW, height: fH - ashY),
        contextHeight: fH
    )
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Narawas/Ngahuru.xcassets/ngahuru_after.imageset/ngahuru_after.png")
}

// MARK: - 3. Ngaseuk Before (ngaseuk_before) - Reference Chapter!
print("Rendering ngaseuk_before (NO STICK, warm closer field framing)...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    
    // Frame a closer view of the field:
    // Mountains and sky occupy upper 32%, rich warm soil occupies lower 68%
    let scale = (fH + 160) / fH
    let width = fW * scale
    drawImage(in: ctx, image: humaEnv, x: (fW - width) / 2, y: -160,
              width: width, height: fH + 160, contextHeight: fH)
    
    // Foreground soil richly detailed with HumaTerrainTexture
    let soilTop: CGFloat = 480.0
    tileImage(in: ctx, image: terrainTex, x: 0, y: soilTop, width: fW, height: fH - soilTop, tileSize: 620, contextHeight: fH, blendMode: .overlay, alpha: 0.52)
    
    // Soft atmospheric warmth
    drawVerticalGradient(
        in: ctx,
        topColor: (1.0, 0.92, 0.78, 0.12),
        bottomColor: (0.12, 0.08, 0.04, 0.22),
        rect: CGRect(x: 0, y: 0, width: fW, height: fH),
        contextHeight: fH
    )
    
    // Clean soil ready for dibbling - ABSOLUTELY NO STICK!
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Ngaseuk/Ngaseuk.xcassets/ngaseuk_before.imageset/ngaseuk_before.png")
}

// MARK: - 4. Ngaseuk After (ngaseuk_after)
print("Rendering ngaseuk_after...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    let scale = (fH + 160) / fH
    let width = fW * scale
    drawImage(in: ctx, image: humaEnv, x: (fW - width) / 2, y: -160,
              width: width, height: fH + 160, contextHeight: fH)
    let soilTop: CGFloat = 480.0
    tileImage(in: ctx, image: terrainTex, x: 0, y: soilTop, width: fW, height: fH - soilTop, tileSize: 620, contextHeight: fH, blendMode: .overlay, alpha: 0.52)
    
    // The three small seeded planting holes in the soil
    // Hole 0: (x: 256, y: 937)
    drawDibbleHole(in: ctx, center: CGPoint(x: 256, y: 937), width: 68, height: 36, withSeeds: true)
    // Hole 1: (x: 512, y: 1014)
    drawDibbleHole(in: ctx, center: CGPoint(x: 512, y: 1014), width: 74, height: 38, withSeeds: true)
    // Hole 2: (x: 768, y: 937)
    drawDibbleHole(in: ctx, center: CGPoint(x: 768, y: 937), width: 68, height: 36, withSeeds: true)
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Ngaseuk/Ngaseuk.xcassets/ngaseuk_after.imageset/ngaseuk_after.png")
}

// MARK: - 5. Ngored Before (ngored_before)
print("Rendering ngored_before...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.35)
    
    // Young rice tufts growing naturally across the field
    drawImage(in: ctx, image: youngRiceTex, x: 60, y: 560, width: 340, height: 340, contextHeight: fH)
    drawImage(in: ctx, image: youngRiceTex, x: 340, y: 550, width: 350, height: 350, contextHeight: fH)
    drawImage(in: ctx, image: youngRiceTex, x: 620, y: 565, width: 340, height: 340, contextHeight: fH)
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Ngored/Ngored.xcassets/ngored_before.imageset/ngored_before.png")
}

// MARK: - 6. Ngored After (ngored_after) - Cleaned Field, NO WEEDS in background!
print("Rendering ngored_after (NO WEEDS in background, clean standing young rice)...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.35)
    
    // Healthy young rice stands in midground (y: 540-840)
    // Notice: leaves the 8 weed interactive spots (y: 875 and 1105) completely clear!
    drawImage(in: ctx, image: youngRiceTex, x: 40, y: 550, width: 360, height: 360, contextHeight: fH)
    drawImage(in: ctx, image: youngRiceTex, x: 330, y: 540, width: 370, height: 370, contextHeight: fH)
    drawImage(in: ctx, image: youngRiceTex, x: 630, y: 555, width: 360, height: 360, contextHeight: fH)
    
    // Clean, freshly watered soil with subtle post-rain sheen
    drawVerticalGradient(
        in: ctx,
        topColor: (0.75, 0.85, 0.95, 0.12),
        bottomColor: (0.10, 0.08, 0.06, 0.20),
        rect: CGRect(x: 0, y: 650, width: fW, height: fH - 650),
        contextHeight: fH
    )
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Ngored/Ngored.xcassets/ngored_after.imageset/ngored_after.png")
}

// MARK: - 7. Mipit Before (mipit_before) - Aligned with Harvest Targets!
print("Rendering mipit_before (ripe golden rice with panicles aligned to harvest targets)...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.28)
    
    // Warm golden afternoon light
    drawVerticalGradient(
        in: ctx,
        topColor: (1.0, 0.88, 0.58, 0.22),
        bottomColor: (0.28, 0.18, 0.08, 0.25),
        rect: CGRect(x: 0, y: 0, width: fW, height: fH),
        contextHeight: fH
    )
    
    // Background mature rice field
    for rx in stride(from: 30, to: 950, by: 120) {
        drawRipePanicle(in: ctx, origin: CGPoint(x: CGFloat(rx), y: 540), bendDirection: (rx % 240 == 0 ? 1 : -1), scale: 0.75)
    }
    
    // 3 Harvest Targets:
    // Target 0: (x: 0.24 * 1024 = 246, y: 0.43 * 1536 = 660)
    drawRipePanicle(in: ctx, origin: CGPoint(x: 246 - 25, y: 660 - 50), bendDirection: 1, scale: 1.15)
    // Target 1: (x: 0.47 * 1024 = 481, y: 0.55 * 1536 = 845)
    drawRipePanicle(in: ctx, origin: CGPoint(x: 481 - 20, y: 845 - 60), bendDirection: -1, scale: 1.25)
    // Target 2: (x: 0.73 * 1024 = 747, y: 0.53 * 1536 = 814)
    drawRipePanicle(in: ctx, origin: CGPoint(x: 747 - 30, y: 814 - 55), bendDirection: 1, scale: 1.20)
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Mipit/Mipit.xcassets/mipit_before.imageset/mipit_before.png")
}

// MARK: - 8. Mipit After (mipit_after)
print("Rendering mipit_after...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.32)
    
    // Harvested field with cut stalks and gathered rice bundles
    drawRiceBundle(in: ctx, center: CGPoint(x: 380, y: 920), width: 110, height: 160)
    drawRiceBundle(in: ctx, center: CGPoint(x: 520, y: 940), width: 115, height: 165)
    drawRiceBundle(in: ctx, center: CGPoint(x: 650, y: 910), width: 105, height: 155)
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Mipit/Mipit.xcassets/mipit_after.imageset/mipit_after.png")
}

// MARK: - 9. Drying Rice Before (drying_rice_before) - Dedicated Landscape Balancing View!
print("Rendering drying_rice_before (landscape huma clearing with mountains)...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    // Wide huma clearing with sky and mountains
    drawImage(in: ctx, image: humaEnv, x: 0, y: 0, width: fW, height: fH, contextHeight: fH)
    
    // Soft horizontal horizon line and clean warm soil
    let soilTop: CGFloat = 680.0
    tileImage(in: ctx, image: terrainTex, x: 0, y: soilTop, width: fW, height: fH - soilTop, tileSize: 512, contextHeight: fH, blendMode: .overlay, alpha: 0.38)
    
    drawVerticalGradient(
        in: ctx,
        topColor: (1.0, 0.95, 0.82, 0.15),
        bottomColor: (0.15, 0.10, 0.05, 0.25),
        rect: CGRect(x: 0, y: 0, width: fW, height: fH),
        contextHeight: fH
    )
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Mipit/Mipit.xcassets/drying_rice_before.imageset/drying_rice_before.png")
}

// MARK: - 10. Drying Rice After (drying_rice_after) - Bamboo Drying Rack (Lantayan)
print("Rendering drying_rice_after (bamboo drying rack in huma clearing)...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    drawHumaBase(in: ctx, soilBlend: 0.32)
    
    // Traditional bamboo drying rack (lantayan)
    let rackLeft: CGFloat = 180
    let rackRight: CGFloat = 844
    let rackTopY: CGFloat = 720
    let rackLegBotY: CGFloat = 1120
    
    // Upright bamboo poles
    let bambooColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.76, 0.65, 0.38, 1.0])!
    let bambooShadow = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.42, 0.32, 0.16, 1.0])!
    
    ctx.saveGState()
    // Left A-frame
    ctx.setStrokeColor(bambooShadow)
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    var p = CGMutablePath()
    p.move(to: CGPoint(x: rackLeft - 30, y: fH - rackLegBotY))
    p.addLine(to: CGPoint(x: rackLeft, y: fH - rackTopY))
    p.addLine(to: CGPoint(x: rackLeft + 30, y: fH - rackLegBotY))
    // Right A-frame
    p.move(to: CGPoint(x: rackRight - 30, y: fH - rackLegBotY))
    p.addLine(to: CGPoint(x: rackRight, y: fH - rackTopY))
    p.addLine(to: CGPoint(x: rackRight + 30, y: fH - rackLegBotY))
    ctx.addPath(p)
    ctx.strokePath()
    
    // Crossbar
    p = CGMutablePath()
    p.move(to: CGPoint(x: rackLeft - 50, y: fH - (rackTopY + 15)))
    p.addLine(to: CGPoint(x: rackRight + 50, y: fH - (rackTopY + 15)))
    ctx.setStrokeColor(bambooColor)
    ctx.setLineWidth(16)
    ctx.addPath(p)
    ctx.strokePath()
    ctx.restoreGState()
    
    // Golden rice bundles hung over the bamboo crossbar
    for i in 1...3 {
        let bx = rackLeft + CGFloat(i) * ((rackRight - rackLeft) / 4)
        drawRiceBundle(in: ctx, center: CGPoint(x: bx, y: rackTopY + 55), width: 128, height: 180)
    }
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/Mipit/Mipit.xcassets/drying_rice_after.imageset/drying_rice_after.png")
}

// MARK: - 11. Leuit Before (ngaleuitkeun_pare_before) - Granary Beside Shared Huma
print("Rendering ngaleuitkeun_pare_before...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    // Base huma with mountains and soil visible
    drawHumaBase(in: ctx, soilBlend: 0.35)
    
    let leuitX: CGFloat = 210
    let leuitY: CGFloat = 430
    let leuitW: CGFloat = 604
    ctx.setFillColor(CGColor(red: 0.14, green: 0.09, blue: 0.05, alpha: 0.36))
    ctx.fillEllipse(in: cgRect(x: 215, y: 978, width: 650, height: 65, contextHeight: fH))
    let side = CGMutablePath()
    side.move(to: CGPoint(x: 770, y: fH - 665))
    side.addLines(between: [
        CGPoint(x: 770, y: fH - 665), CGPoint(x: 850, y: fH - 630),
        CGPoint(x: 850, y: fH - 910), CGPoint(x: 770, y: fH - 950)
    ])
    side.closeSubpath()
    ctx.setFillColor(CGColor(red: 0.39, green: 0.28, blue: 0.15, alpha: 1))
    ctx.addPath(side)
    ctx.fillPath()
    
    // 1. Foundation stone discs & wooden posts (at y: 880-1040)
    let postColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.38, 0.24, 0.12, 1.0])!
    let stoneColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.55, 0.52, 0.48, 1.0])!
    ctx.saveGState()
    for px in [leuitX + 60, leuitX + leuitW/2, leuitX + leuitW - 60] {
        // Stone disc
        let stoneR = cgRect(x: px - 25, y: 990, width: 50, height: 24, contextHeight: fH)
        ctx.setFillColor(stoneColor)
        ctx.fillEllipse(in: stoneR)
        // Timber post
        let postR = cgRect(x: px - 14, y: 840, width: 28, height: 160, contextHeight: fH)
        ctx.setFillColor(postColor)
        ctx.fill(postR)
    }
    ctx.restoreGState()
    
    // 2. Woven bamboo walls (gedek)
    let bodyR = cgRect(x: leuitX + 30, y: leuitY + 240, width: leuitW - 60, height: 280, contextHeight: fH)
    ctx.saveGState()
    ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.72, 0.58, 0.36, 1.0])!)
    ctx.fill(bodyR)
    // Wood texture overlay on walls
    tileImage(in: ctx, image: woodTex, x: leuitX + 30, y: leuitY + 240, width: leuitW - 60, height: 280, tileSize: 256, contextHeight: fH, blendMode: .multiply, alpha: 0.45)
    ctx.restoreGState()
    
    // 3. Three small granary doorway openings aligned at y ≈ 660 (y = 0.43 * 1536)
    ctx.saveGState()
    let doorColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.12, 0.07, 0.03, 1.0])!
    for dx in [fW * 0.25, fW * 0.50, fW * 0.75] {
        let dR = cgRect(x: dx - 40, y: 640, width: 80, height: 95, contextHeight: fH)
        ctx.setFillColor(doorColor)
        ctx.fill(dR)
        ctx.setStrokeColor(postColor)
        ctx.setLineWidth(5)
        ctx.stroke(dR)
    }
    ctx.restoreGState()
    
    // 4. Steep Thatched Gabled Roof (Ijuk / thatch)
    ctx.saveGState()
    let roofPath = CGMutablePath()
    let roofTop = CGPoint(x: fW/2, y: fH - leuitY)
    let roofLeft = CGPoint(x: leuitX - 60, y: fH - (leuitY + 270))
    let roofRight = CGPoint(x: leuitX + leuitW + 60, y: fH - (leuitY + 270))
    roofPath.move(to: roofTop)
    roofPath.addLine(to: roofRight)
    roofPath.addLine(to: roofLeft)
    roofPath.closeSubpath()
    
    ctx.addPath(roofPath)
    ctx.clip()
    tileImage(in: ctx, image: thatchTex, x: leuitX - 70, y: leuitY, width: leuitW + 140, height: 300, tileSize: 400, contextHeight: fH, blendMode: .normal, alpha: 0.92)
    ctx.restoreGState()
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/NgaleuitkeunPare/NgaleuitkeunPare.xcassets/ngaleuitkeun_pare_before.imageset/ngaleuitkeun_pare_before.png")
}

// MARK: - 12. Leuit After (ngaleuitkeun_pare_after) - Granary Interior View!
print("Rendering ngaleuitkeun_pare_after (distinct visually related interior with stored rice bundles)...")
do {
    let ctx = createBitmapContext(width: W, height: H)
    
    // Interior view through open wooden doorway
    // 1. Back and side woven bamboo walls
    tileImage(in: ctx, image: woodTex, x: 0, y: 0, width: fW, height: fH * 0.65, tileSize: 400, contextHeight: fH, blendMode: .normal, alpha: 0.85)
    
    // 2. Ceiling timber beams & thatch eaves
    let ceilingR = CGRect(x: 0, y: 0, width: fW, height: fH * 0.28)
    tileImage(in: ctx, image: thatchTex, x: 0, y: 0, width: fW, height: fH * 0.28, tileSize: 380, contextHeight: fH, blendMode: .multiply, alpha: 0.75)
    
    // 3. Elevated wooden floorboards (planks)
    let floorY = fH * 0.60
    let floorH = fH * 0.40
    tileImage(in: ctx, image: woodTex, x: 0, y: floorY, width: fW, height: floorH, tileSize: 512, contextHeight: fH, blendMode: .normal, alpha: 0.95)
    
    // Draw floor plank lines
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.18, 0.10, 0.04, 0.75])!)
    ctx.setLineWidth(4)
    for px in stride(from: 80, to: Int(fW), by: 95) {
        let pLine = CGMutablePath()
        pLine.move(to: CGPoint(x: CGFloat(px), y: fH - floorY))
        pLine.addLine(to: CGPoint(x: CGFloat(px) * 1.15 - 50, y: 0))
        ctx.addPath(pLine)
        ctx.strokePath()
    }
    ctx.restoreGState()
    
    // 4. Stacks of dry golden rice bundles (poc padi) neatly placed on the floor
    for r in 0..<3 {
        let rowY = floorY + 40 + CGFloat(r) * 65
        let count = 4 + r
        let spacing = fW / CGFloat(count + 1)
        for c in 0..<count {
            let bx = spacing * CGFloat(c + 1) + CGFloat((r % 2 == 0 ? 15 : -15))
            drawRiceBundle(in: ctx, center: CGPoint(x: bx, y: rowY), width: 95 + CGFloat(r * 10), height: 140 + CGFloat(r * 15))
        }
    }
    
    // 5. Warm natural daylight streaming through entrance
    drawVerticalGradient(
        in: ctx,
        topColor: (1.0, 0.95, 0.85, 0.35),
        bottomColor: (0.15, 0.08, 0.03, 0.50),
        rect: CGRect(x: 0, y: 0, width: fW, height: fH),
        contextHeight: fH
    )
    
    guard let img = ctx.makeImage() else { fatalError() }
    savePNG(image: img, to: "BeBaduy/Asset/NgaleuitkeunPare/NgaleuitkeunPare.xcassets/ngaleuitkeun_pare_after.imageset/ngaleuitkeun_pare_after.png")
}

print("All 12 huma artwork images successfully generated!")
