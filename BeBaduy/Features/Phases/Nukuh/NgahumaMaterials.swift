import SceneKit
import UIKit

/// Spatial 3-layer environment and HomeView-matched 3D assets for the Nukuh AR experience.
@MainActor
struct NgahumaMaterials {
    let skyTexture: UIImage
    let mountainTexture: UIImage
    let horizonGrassTexture: UIImage
    let soilTexture: UIImage
    let charredSoilTexture: UIImage
    let grassBladeTexture: UIImage
    let treeTexture: UIImage
    let rootFlareTexture: UIImage
    let woodTexture: UIImage
    let leafNormal: UIImage
    let particleSprite: UIImage
    let sunHaloSprite: UIImage
    let woodSplinterSprite: UIImage
    let woodChipSprite: UIImage

    static func load() async throws -> Self {
        guard let environment = UIImage(named: "HumaEnvironment"),
              let envCG = environment.cgImage else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard let skyCG = Self.build360Panorama(from: envCG),
              let mountainCG = Self.buildMountainRidgeLayer(from: envCG),
              let horizonGrassCG = Self.buildHorizonGrassLayer(from: envCG),
              let soilCG = Self.buildSoilTexture(from: envCG) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let skyTexture = UIImage(cgImage: skyCG)
        let mountainTexture = UIImage(cgImage: mountainCG)
        let horizonGrassTexture = UIImage(cgImage: horizonGrassCG)
        let soilTexture = UIImage(cgImage: soilCG)
        let charredSoilTexture = Self.buildCharredSoilTexture(from: soilCG)

        let grassBladeTexture = UIImage(named: "HumaGrassTexture")
            ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "ngahuma-grass", ofType: "png") ?? "")
            ?? UIImage()

        let treeTexture = UIImage(named: "HumaTreeNatural")
            ?? UIImage(named: "HumaTree")
            ?? UIImage()

        let rootFlareTexture = Self.extractRootFlareTexture(from: treeTexture)

        let woodTexture = UIImage(named: "HumaWoodTexture") ?? UIImage()
        let leafNormal = Self.makeDetailNormal(frequency: 22, strength: 0.12)
        let particleSprite = Self.makeParticleSprite()
        let sunHaloSprite = Self.makeSunHaloSprite()
        let woodSplinterSprite = Self.makeWoodSplinterSprite()
        let woodChipSprite = Self.makeWoodChipSprite()

        return Self(
            skyTexture: skyTexture,
            mountainTexture: mountainTexture,
            horizonGrassTexture: horizonGrassTexture,
            soilTexture: soilTexture,
            charredSoilTexture: charredSoilTexture,
            grassBladeTexture: grassBladeTexture,
            treeTexture: treeTexture,
            rootFlareTexture: rootFlareTexture,
            woodTexture: woodTexture,
            leafNormal: leafNormal,
            particleSprite: particleSprite,
            sunHaloSprite: sunHaloSprite,
            woodSplinterSprite: woodSplinterSprite,
            woodChipSprite: woodChipSprite
        )
    }

    // MARK: - Layer 1 (Back): 360° Sky Layer ("layer langit")

    /// Generates the outermost 360° sky layer from the clean upper sky of HumaEnvironment
    /// using cosine overlap cross-blending (no mirror seams).
    static func build360Panorama(from source: CGImage) -> CGImage? {
        guard let data = source.dataProvider?.data,
              let srcPtr = CFDataGetBytePtr(data) else { return nil }
        let srcW = source.width
        let srcH = source.height
        let bpr = source.bytesPerRow
        let bpp = max(4, source.bitsPerPixel / 8)

        let panoW = 2048
        let panoH = 1024
        let tileW = 1024
        let sx0 = 330.0
        let sx1 = 870.0
        let totalW = sx1 - sx0 // 540
        let overlap = 150.0
        let periodW = totalW - overlap // 390

        let skyBandYTop = 150
        let skyBandYBot = 560
        let skyBandH = Double(skyBandYBot - skyBandYTop)

        var outPixels = [UInt8](repeating: 255, count: panoW * panoH * 4)

        func sampleSky(_ x: Double, _ y: Double) -> (Double, Double, Double) {
            let cx = max(0.0, min(Double(srcW - 2), x))
            let cy = max(0.0, min(Double(srcH - 2), y))
            let x0 = Int(cx), y0 = Int(cy)
            let fx = cx - Double(x0), fy = cy - Double(y0)
            func pix(_ ix: Int, _ iy: Int) -> (Double, Double, Double) {
                let p = iy * bpr + ix * bpp
                return (Double(srcPtr[p]), Double(srcPtr[p + 1]), Double(srcPtr[p + 2]))
            }
            let c00 = pix(x0, y0), c10 = pix(x0 + 1, y0)
            let c01 = pix(x0, y0 + 1), c11 = pix(x0 + 1, y0 + 1)
            return (
                (1 - fx) * (1 - fy) * c00.0 + fx * (1 - fy) * c10.0 + (1 - fx) * fy * c01.0 + fx * fy * c11.0,
                (1 - fx) * (1 - fy) * c00.1 + fx * (1 - fy) * c10.1 + (1 - fx) * fy * c01.1 + fx * fy * c11.1,
                (1 - fx) * (1 - fy) * c00.2 + fx * (1 - fy) * c10.2 + (1 - fx) * fy * c01.2 + fx * fy * c11.2
            )
        }

        for oy in 0..<panoH {
            let v = Double(oy) / Double(panoH - 1)
            // Base vertical sky gradient (zenith -> golden cloud horizon -> nadir)
            let gradR: Double
            let gradG: Double
            let gradB: Double
            if v < 0.28 {
                let t = smoothstep(0.0, 0.28, v)
                gradR = (1 - t) * 132.0 + t * 176.0
                gradG = (1 - t) * 144.0 + t * 178.0
                gradB = (1 - t) * 162.0 + t * 184.0
            } else if v < 0.52 {
                let t = smoothstep(0.28, 0.52, v)
                gradR = (1 - t) * 176.0 + t * 232.0
                gradG = (1 - t) * 178.0 + t * 206.0
                gradB = (1 - t) * 184.0 + t * 180.0
            } else if v < 0.68 {
                let t = smoothstep(0.52, 0.68, v)
                gradR = (1 - t) * 232.0 + t * 112.0
                gradG = (1 - t) * 206.0 + t * 88.0
                gradB = (1 - t) * 180.0 + t * 66.0
            } else {
                let t = smoothstep(0.68, 1.0, v)
                gradR = (1 - t) * 112.0 + t * 68.0
                gradG = (1 - t) * 88.0 + t * 48.0
                gradB = (1 - t) * 66.0 + t * 34.0
            }

            let inBand = oy >= skyBandYTop && oy <= skyBandYBot
            let bandT = inBand ? (Double(oy - skyBandYTop) / skyBandH) : 0.0
            let bandWeight = inBand ? (smoothstep(0.0, 0.22, bandT) * (1.0 - smoothstep(0.78, 1.0, bandT))) : 0.0
            let srcY = 12.0 + bandT * 305.0

            for ox in 0..<tileW {
                var r = gradR, g = gradG, b = gradB
                if bandWeight > 0.001 {
                    let u = Double(ox) / Double(tileW)
                    let s = u * periodW
                    let inBlend = s < overlap
                    let w = inBlend ? (0.5 - 0.5 * cos(.pi * s / overlap)) : 1.0
                    let cA = sampleSky(sx0 + s, srcY)
                    var cr = cA.0, cg = cA.1, cb = cA.2
                    if inBlend {
                        let cB = sampleSky(sx0 + periodW + s, srcY)
                        cr = (1.0 - w) * cB.0 + w * cA.0
                        cg = (1.0 - w) * cB.1 + w * cA.1
                        cb = (1.0 - w) * cB.2 + w * cA.2
                    }
                    r = (1.0 - bandWeight) * gradR + bandWeight * cr
                    g = (1.0 - bandWeight) * gradG + bandWeight * cg
                    b = (1.0 - bandWeight) * gradB + bandWeight * cb
                }
                let pr = UInt8(max(0, min(255, Int(r.rounded()))))
                let pg = UInt8(max(0, min(255, Int(g.rounded()))))
                let pb = UInt8(max(0, min(255, Int(b.rounded()))))
                let idx0 = (oy * panoW + ox) * 4
                let idx1 = (oy * panoW + ox + tileW) * 4
                outPixels[idx0] = pr; outPixels[idx0 + 1] = pg; outPixels[idx0 + 2] = pb; outPixels[idx0 + 3] = 255
                outPixels[idx1] = pr; outPixels[idx1 + 1] = pg; outPixels[idx1 + 2] = pb; outPixels[idx1 + 3] = 255
            }
        }

        let provider = CGDataProvider(data: Data(outPixels) as CFData)!
        return CGImage(
            width: panoW,
            height: panoH,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: panoW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Layer 2 (Middle): 360° Mountain Ridge Layer ("gunung-gunungan")

    /// Extracts the mountain ridge & misty valley layer from HumaEnvironment using:
    /// 1. Per-column pixel gradient ridge detection smoothed with a Gaussian kernel,
    /// 2. Soft 6.5px alpha feathering along the mountain crest (no polygonal clip or stroke outline),
    /// 3. Horizon-leveled, contour-aligned cosine cross-blending (no mirror cusp `/\` or vertical seam),
    /// 4. Output size: 2048 × 512 (repeating the seamless period 2× across 360°).
    static func buildMountainRidgeLayer(from source: CGImage) -> CGImage? {
        guard let data = source.dataProvider?.data,
              let srcPtr = CFDataGetBytePtr(data) else { return nil }
        let srcW = source.width
        let srcH = source.height
        let bpr = source.bytesPerRow
        let bpp = max(4, source.bitsPerPixel / 8)

        func sampleRGB(_ x: Double, _ y: Double) -> (Double, Double, Double) {
            let cx = max(0.0, min(Double(srcW - 2), x))
            let cy = max(0.0, min(Double(srcH - 2), y))
            let x0 = Int(cx), y0 = Int(cy)
            let fx = cx - Double(x0), fy = cy - Double(y0)
            func pix(_ ix: Int, _ iy: Int) -> (Double, Double, Double) {
                let p = iy * bpr + ix * bpp
                return (Double(srcPtr[p]), Double(srcPtr[p + 1]), Double(srcPtr[p + 2]))
            }
            let c00 = pix(x0, y0), c10 = pix(x0 + 1, y0)
            let c01 = pix(x0, y0 + 1), c11 = pix(x0 + 1, y0 + 1)
            return (
                (1 - fx) * (1 - fy) * c00.0 + fx * (1 - fy) * c10.0 + (1 - fx) * fy * c01.0 + fx * fy * c11.0,
                (1 - fx) * (1 - fy) * c00.1 + fx * (1 - fy) * c10.1 + (1 - fx) * fy * c01.1 + fx * fy * c11.1,
                (1 - fx) * (1 - fy) * c00.2 + fx * (1 - fy) * c10.2 + (1 - fx) * fy * c01.2 + fx * fy * c11.2
            )
        }

        // Detect exact per-column sky-to-mountain ridge transition
        var rawRidge = [Double](repeating: 370.0, count: srcW)
        for x in 180..<min(srcW, 870) {
            var bestY = 370
            var bestScore = -1e9
            for y in 332..<min(srcH - 5, 405) {
                let pAbove = (y - 4) * bpr + x * bpp
                let pBelow = (y + 4) * bpr + x * bpp
                let r0 = Double(srcPtr[pAbove]), g0 = Double(srcPtr[pAbove + 1]), b0 = Double(srcPtr[pAbove + 2])
                let r1 = Double(srcPtr[pBelow]), g1 = Double(srcPtr[pBelow + 1]), b1 = Double(srcPtr[pBelow + 2])
                guard r1 < 169.0 else { continue }
                let drop = (r0 - r1) * 1.5 + (g0 - g1) * 1.0 + ((r0 - b0) - (r1 - b1)) * 1.2
                if drop > bestScore {
                    bestScore = drop
                    bestY = y
                }
            }
            rawRidge[x] = Double(bestY)
        }

        // Smooth ridge profile with 4 passes of a Gaussian kernel so the silhouette has zero jagged corners
        var smoothRidge = rawRidge
        for _ in 0..<4 {
            var next = smoothRidge
            for x in 195..<min(srcW - 11, 855) {
                var sum = 0.0, wSum = 0.0
                for dx in -10...10 {
                    let w = exp(-Double(dx * dx) / 36.0)
                    sum += smoothRidge[x + dx] * w
                    wSum += w
                }
                next[x] = sum / wSum
            }
            smoothRidge = next
        }

        func ridgeAt(_ x: Double) -> Double {
            let cx = max(200.0, min(Double(srcW - 2), min(850.0, x)))
            let x0 = Int(cx)
            let fx = cx - Double(x0)
            return (1.0 - fx) * smoothRidge[x0] + fx * smoothRidge[min(srcW - 1, x0 + 1)]
        }

        let outW = 2048
        let outH = 512
        let tileW = 1024
        let srcX0 = 225.0
        let srcX1 = 835.0
        let totalW = srcX1 - srcX0
        let overlap = 175.0
        let periodW = totalW - overlap
        let srcYTop = 315.0
        let srcYBot = 665.0 // Includes the natural ridge grass and horizon vegetation!
        let srcYH = srcYBot - srcYTop
        let targetSoilY = 634.0

        var mPixels = [UInt8](repeating: 0, count: outW * outH * 4)

        for ox in 0..<tileW {
            let u = Double(ox) / Double(tileW)
            let s = u * periodW
            let inBlend = s < overlap
            let w = inBlend ? (0.5 - 0.5 * cos(.pi * s / overlap)) : 1.0
            let xA = srcX0 + s
            let xB = srcX0 + periodW + s

            let rA = ridgeAt(xA), sA = soilHorizonAt(xA)
            let rB = ridgeAt(xB), sB = soilHorizonAt(xB)
            let leveledRA = rA + (targetSoilY - sA)
            let leveledRB = rB + (targetSoilY - sB)
            let targetR = inBlend ? ((1.0 - w) * leveledRB + w * leveledRA) : leveledRA

            func mapY(_ y: Double, _ rSrc: Double, _ sSrc: Double) -> Double {
                if y <= targetR {
                    return rSrc + (y - targetR)
                } else if y <= targetSoilY {
                    let frac = (y - targetR) / max(1.0, targetSoilY - targetR)
                    return rSrc + frac * (sSrc - rSrc)
                } else {
                    return sSrc + (y - targetSoilY)
                }
            }

            for oy in 0..<outH {
                let v = Double(oy) / Double(outH - 1)
                let targetY = srcYTop + v * srcYH

                // Soft 6.5px alpha feather along the natural ridge silhouette (no stroke line!)
                let ridgeAlpha = smoothstep(targetR - 1.0, targetR + 6.5, targetY)
                guard ridgeAlpha > 0.001 else { continue }

                let yA = mapY(targetY, rA, sA)
                let cA = sampleRGB(xA, yA)
                var r = cA.0, g = cA.1, b = cA.2
                if inBlend {
                    let yB = mapY(targetY, rB, sB)
                    let cB = sampleRGB(xB, yB)
                    r = (1.0 - w) * cB.0 + w * cA.0
                    g = (1.0 - w) * cB.1 + w * cA.1
                    b = (1.0 - w) * cB.2 + w * cA.2
                }

                // Preserve all the natural green foliage & horizon trees; gently feather base skirt below soil
                let baseFeather = 1.0 - smoothstep(srcYH - 18.0, srcYH, v * srcYH) * 0.15
                let a = ridgeAlpha * baseFeather

                let pr = UInt8(max(0, min(255, Int((r * a).rounded()))))
                let pg = UInt8(max(0, min(255, Int((g * a).rounded()))))
                let pb = UInt8(max(0, min(255, Int((b * a).rounded()))))
                let pa = UInt8(max(0, min(255, Int((a * 255.0).rounded()))))

                let idx0 = (oy * outW + ox) * 4
                let idx1 = (oy * outW + ox + tileW) * 4
                mPixels[idx0] = pr; mPixels[idx0 + 1] = pg; mPixels[idx0 + 2] = pb; mPixels[idx0 + 3] = pa
                mPixels[idx1] = pr; mPixels[idx1 + 1] = pg; mPixels[idx1 + 2] = pb; mPixels[idx1 + 3] = pa
            }
        }

        let provider = CGDataProvider(data: Data(mPixels) as CFData)!
        return CGImage(
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: outW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Layer 3a (Foreground Horizon): 360° Grass & Soil Rim Layer

    /// Extracts the sunlit horizon grass rim of HumaEnvironment with soft top & bottom alpha
    /// feathering and cosine overlap cross-blending (zero polygonal cutout, zero mirror cusp).
    /// Output size: 2048 × 256.
    static func buildHorizonGrassLayer(from source: CGImage) -> CGImage? {
        guard let data = source.dataProvider?.data,
              let srcPtr = CFDataGetBytePtr(data) else { return nil }
        let srcW = source.width
        let srcH = source.height
        let bpr = source.bytesPerRow
        let bpp = max(4, source.bitsPerPixel / 8)

        func sampleRGB(_ x: Double, _ y: Double) -> (Double, Double, Double) {
            let cx = max(0.0, min(Double(srcW - 2), x))
            let cy = max(0.0, min(Double(srcH - 2), y))
            let x0 = Int(cx), y0 = Int(cy)
            let fx = cx - Double(x0), fy = cy - Double(y0)
            func pix(_ ix: Int, _ iy: Int) -> (Double, Double, Double) {
                let p = iy * bpr + ix * bpp
                return (Double(srcPtr[p]), Double(srcPtr[p + 1]), Double(srcPtr[p + 2]))
            }
            let c00 = pix(x0, y0), c10 = pix(x0 + 1, y0)
            let c01 = pix(x0, y0 + 1), c11 = pix(x0 + 1, y0 + 1)
            return (
                (1 - fx) * (1 - fy) * c00.0 + fx * (1 - fy) * c10.0 + (1 - fx) * fy * c01.0 + fx * fy * c11.0,
                (1 - fx) * (1 - fy) * c00.1 + fx * (1 - fy) * c10.1 + (1 - fx) * fy * c01.1 + fx * fy * c11.1,
                (1 - fx) * (1 - fy) * c00.2 + fx * (1 - fy) * c10.2 + (1 - fx) * fy * c01.2 + fx * fy * c11.2
            )
        }

        let outW = 2048
        let outH = 256
        let tileW = 1024
        let srcX0 = 225.0
        let srcX1 = 835.0
        let totalW = srcX1 - srcX0
        let overlap = 175.0
        let periodW = totalW - overlap
        let gYTop = 540.0
        let gYBot = 665.0
        let gYH = gYBot - gYTop
        let targetSoilY = 634.0

        var gPixels = [UInt8](repeating: 0, count: outW * outH * 4)

        for ox in 0..<tileW {
            let u = Double(ox) / Double(tileW)
            let s = u * periodW
            let inBlend = s < overlap
            let w = inBlend ? (0.5 - 0.5 * cos(.pi * s / overlap)) : 1.0
            let xA = srcX0 + s
            let xB = srcX0 + periodW + s
            let sA = soilHorizonAt(xA), sB = soilHorizonAt(xB)

            for oy in 0..<outH {
                let v = Double(oy) / Double(outH - 1)
                let targetY = gYTop + v * gYH
                let yA = targetY + (sA - targetSoilY)
                let cA = sampleRGB(xA, yA)
                var r = cA.0, g = cA.1, b = cA.2
                if inBlend {
                    let yB = targetY + (sB - targetSoilY)
                    let cB = sampleRGB(xB, yB)
                    r = (1.0 - w) * cB.0 + w * cA.0
                    g = (1.0 - w) * cB.1 + w * cA.1
                    b = (1.0 - w) * cB.2 + w * cA.2
                }

                // Soft feathered top fade + chroma key for sunlit yellow-green grass tips
                let grassKey = max(0.0, min(1.0, ((g - b) - 14.0) / 24.0))
                let topFade = smoothstep(550.0, 595.0, targetY) * (0.40 + 0.60 * grassKey)
                let botFade = 1.0 - smoothstep(646.0, 665.0, targetY)
                let a = max(0.0, min(1.0, topFade * botFade))

                let pr = UInt8(max(0, min(255, Int((r * a).rounded()))))
                let pg = UInt8(max(0, min(255, Int((g * a).rounded()))))
                let pb = UInt8(max(0, min(255, Int((b * a).rounded()))))
                let pa = UInt8(max(0, min(255, Int((a * 255.0).rounded()))))

                let idx0 = (oy * outW + ox) * 4
                let idx1 = (oy * outW + ox + tileW) * 4
                gPixels[idx0] = pr; gPixels[idx0 + 1] = pg; gPixels[idx0 + 2] = pb; gPixels[idx0 + 3] = pa
                gPixels[idx1] = pr; gPixels[idx1 + 1] = pg; gPixels[idx1 + 2] = pb; gPixels[idx1 + 3] = pa
            }
        }

        let provider = CGDataProvider(data: Data(gPixels) as CFData)!
        return CGImage(
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: outW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Layer 3b (Ground): Authentic Rich Photographic Soil from HumaEnvironment

    /// Extracts the authentic brown agricultural soil from HumaEnvironment with pebbles,
    /// soil clods, and natural earth grain, leveling only macro illumination to create
    /// a crisp 1024 × 1024 seamless toroidal texture.
    static func buildSoilTexture(from source: CGImage) -> CGImage? {
        guard let data = source.dataProvider?.data,
              let srcPtr = CFDataGetBytePtr(data) else { return nil }
        let srcW = source.width
        let srcH = source.height
        let bpr = source.bytesPerRow
        let bpp = max(4, source.bitsPerPixel / 8)

        func sampleRGB(_ x: Double, _ y: Double) -> (Double, Double, Double) {
            let cx = max(0.0, min(Double(srcW - 2), x))
            let cy = max(0.0, min(Double(srcH - 2), y))
            let x0 = Int(cx), y0 = Int(cy)
            let fx = cx - Double(x0), fy = cy - Double(y0)
            func pix(_ ix: Int, _ iy: Int) -> (Double, Double, Double) {
                let p = iy * bpr + ix * bpp
                return (Double(srcPtr[p]), Double(srcPtr[p + 1]), Double(srcPtr[p + 2]))
            }
            let c00 = pix(x0, y0), c10 = pix(x0 + 1, y0)
            let c01 = pix(x0, y0 + 1), c11 = pix(x0 + 1, y0 + 1)
            return (
                (1 - fx) * (1 - fy) * c00.0 + fx * (1 - fy) * c10.0 + (1 - fx) * fy * c01.0 + fx * fy * c11.0,
                (1 - fx) * (1 - fy) * c00.1 + fx * (1 - fy) * c10.1 + (1 - fx) * fy * c01.1 + fx * fy * c11.1,
                (1 - fx) * (1 - fy) * c00.2 + fx * (1 - fy) * c10.2 + (1 - fx) * fy * c01.2 + fx * fy * c11.2
            )
        }

        let patchSize = 512
        let sx0 = 220.0, sxW = min(580.0, Double(max(1, srcW - 230)))
        let sy0 = min(700.0, Double(max(0, srcH - 560))), syH = min(550.0, Double(max(1, srcH - Int(sy0) - 1)))

        var rawSoil = [(Double, Double, Double)](repeating: (0, 0, 0), count: patchSize * patchSize)
        for py in 0..<patchSize {
            let v = Double(py) / Double(patchSize)
            let y = sy0 + v * syH
            for px in 0..<patchSize {
                let u = Double(px) / Double(patchSize)
                let x = sx0 + u * sxW
                rawSoil[py * patchSize + px] = sampleRGB(x, y)
            }
        }

        // Low-frequency illumination profile (separable blur, radius = 32)
        var hBlur = rawSoil
        let blurR = 32
        for py in 0..<patchSize {
            for px in 0..<patchSize {
                var r = 0.0, g = 0.0, b = 0.0, c = 0.0
                for dx in -blurR...blurR {
                    let x = max(0, min(patchSize - 1, px + dx))
                    let v = rawSoil[py * patchSize + x]
                    r += v.0; g += v.1; b += v.2; c += 1.0
                }
                hBlur[py * patchSize + px] = (r / c, g / c, b / c)
            }
        }
        var lowFreq = hBlur
        for py in 0..<patchSize {
            for px in 0..<patchSize {
                var r = 0.0, g = 0.0, b = 0.0, c = 0.0
                for dy in -blurR...blurR {
                    let y = max(0, min(patchSize - 1, py + dy))
                    let v = hBlur[y * patchSize + px]
                    r += v.0; g += v.1; b += v.2; c += 1.0
                }
                lowFreq[py * patchSize + px] = (r / c, g / c, b / c)
            }
        }

        let meanR = 108.0, meanG = 76.0, meanB = 52.0
        var normalizedSoil = [(Double, Double, Double)](repeating: (0, 0, 0), count: patchSize * patchSize)
        for i in 0..<(patchSize * patchSize) {
            let raw = rawSoil[i]
            let low = lowFreq[i]
            let dr = raw.0 - low.0
            let dg = raw.1 - low.1
            let db = raw.2 - low.2
            normalizedSoil[i] = (
                max(0.0, min(255.0, meanR + dr * 1.05)),
                max(0.0, min(255.0, meanG + dg * 1.05)),
                max(0.0, min(255.0, meanB + db * 1.05))
            )
        }

        // Toroidal seamless blending (period = 384, overlap = 128)
        let period = 384
        let overlap = patchSize - period // 128
        let outSize = 1024
        var outPixels = [UInt8](repeating: 255, count: outSize * outSize * 4)

        for y in 0..<outSize {
            let ty = Int((Double(y) / Double(outSize)) * Double(period)) % period
            let wy = ty < overlap ? (0.5 - 0.5 * cos(.pi * Double(ty) / Double(overlap))) : 1.0
            for x in 0..<outSize {
                let tx = Int((Double(x) / Double(outSize)) * Double(period)) % period
                let wx = tx < overlap ? (0.5 - 0.5 * cos(.pi * Double(tx) / Double(overlap))) : 1.0

                let c00 = normalizedSoil[ty * patchSize + tx]
                let c10 = normalizedSoil[ty * patchSize + (tx + (tx < overlap ? period : 0))]
                let c01 = normalizedSoil[(ty + (ty < overlap ? period : 0)) * patchSize + tx]
                let c11 = normalizedSoil[(ty + (ty < overlap ? period : 0)) * patchSize + (tx + (tx < overlap ? period : 0))]

                let r = wx * wy * c00.0 + (1 - wx) * wy * c10.0 + wx * (1 - wy) * c01.0 + (1 - wx) * (1 - wy) * c11.0
                let g = wx * wy * c00.1 + (1 - wx) * wy * c10.1 + wx * (1 - wy) * c01.1 + (1 - wx) * (1 - wy) * c11.1
                let b = wx * wy * c00.2 + (1 - wx) * wy * c10.2 + wx * (1 - wy) * c01.2 + (1 - wx) * (1 - wy) * c11.2

                let idx = (y * outSize + x) * 4
                outPixels[idx]     = UInt8(max(0, min(255, Int(r.rounded()))))
                outPixels[idx + 1] = UInt8(max(0, min(255, Int(g.rounded()))))
                outPixels[idx + 2] = UInt8(max(0, min(255, Int(b.rounded()))))
                outPixels[idx + 3] = 255
            }
        }

        let provider = CGDataProvider(data: Data(outPixels) as CFData)!
        return CGImage(
            width: outSize,
            height: outSize,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: outSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    static func createHomeMatchedSoil(from terrainImage: CGImage) -> CGImage? {
        buildSoilTexture(from: terrainImage) ?? terrainImage
    }

    private static func buildCharredSoilTexture(from soilCG: CGImage) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let baseImage = UIImage(cgImage: soilCG)
        let ashOverlay = UIImage(named: "ngahuma-ash")
            ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "ngahuma-ash", ofType: "png") ?? "")

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let ctx = rendererContext.cgContext
            baseImage.draw(in: CGRect(origin: .zero, size: size))
            if let ashOverlay {
                ashOverlay.draw(in: CGRect(origin: .zero, size: size), blendMode: .multiply, alpha: 0.75)
            }
            ctx.setBlendMode(.multiply)
            ctx.setFillColor(UIColor(red: 0.24, green: 0.20, blue: 0.17, alpha: 1.0).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static let soilHorizonPoints: [(Double, Double)] = [
        (0, 672), (150, 645), (300, 634), (440, 634), (600, 625), (780, 607), (1024, 596)
    ]

    private static func soilHorizonAt(_ x: Double) -> Double {
        for i in 0..<(soilHorizonPoints.count - 1) {
            let p0 = soilHorizonPoints[i], p1 = soilHorizonPoints[i + 1]
            if x >= p0.0 && x <= p1.0 {
                let t = (x - p0.0) / max(1e-5, p1.0 - p0.0)
                let s = t * t * (3.0 - 2.0 * t)
                return p0.1 + (p1.1 - p0.1) * s
            }
        }
        return 630.0
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0.0, min(1.0, (x - edge0) / max(1e-5, edge1 - edge0)))
        return t * t * (3.0 - 2.0 * t)
    }

    // MARK: - HomeView (SceneKitCropView) Shared Procedural Textures & Sprites

    private static func extractRootFlareTexture(from treeImage: UIImage) -> UIImage {
        guard let cg = treeImage.cgImage else { return treeImage }
        let bounds = CGRect(
            x: 0,
            y: CGFloat(cg.height) * 0.85,
            width: CGFloat(cg.width),
            height: CGFloat(cg.height) * 0.15
        )
        guard let crop = cg.cropping(to: bounds) else { return treeImage }
        return UIImage(cgImage: crop, scale: treeImage.scale, orientation: treeImage.imageOrientation)
    }

    static func makeDetailNormal(frequency: Float, strength: Float) -> UIImage {
        let size = 128
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let u = Float(x) / Float(size), v = Float(y) / Float(size)
                let slope = sin(u * frequency * 2 * .pi + sin(v * 2 * .pi) * 0.5)
                let n = simd_normalize(SIMD3<Float>(slope * strength, 0.025 * cos(v * 2 * .pi), 1))
                let offset = (y * size + x) * 4
                pixels[offset] = UInt8((n.x * 0.5 + 0.5) * 255)
                pixels[offset + 1] = UInt8((n.y * 0.5 + 0.5) * 255)
                pixels[offset + 2] = UInt8((n.z * 0.5 + 0.5) * 255)
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )!
        return UIImage(cgImage: image)
    }

    static func makeParticleSprite() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 32, y: 32),
                startRadius: 0,
                endCenter: CGPoint(x: 32, y: 32),
                endRadius: 32,
                options: []
            )
        }
    }

    static func makeSunHaloSprite() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
            let colors = [
                UIColor(red: 1.0, green: 0.99, blue: 0.95, alpha: 0.95).cgColor,
                UIColor(red: 1.0, green: 0.93, blue: 0.78, alpha: 0.52).cgColor,
                UIColor(red: 1.0, green: 0.85, blue: 0.64, alpha: 0.18).cgColor,
                UIColor(red: 1.0, green: 0.80, blue: 0.55, alpha: 0.0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.18, 0.48, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: 128, y: 128),
                    startRadius: 0,
                    endCenter: CGPoint(x: 128, y: 128),
                    endRadius: 128,
                    options: []
                )
            }
        }
    }

    static func makeWoodSplinterSprite() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 46, height: 18), format: format)
        return renderer.image { context in
            let cg = context.cgContext
            let shard = UIBezierPath()
            shard.move(to: CGPoint(x: 1, y: 12))
            shard.addLine(to: CGPoint(x: 9, y: 7))
            shard.addLine(to: CGPoint(x: 42, y: 2))
            shard.addLine(to: CGPoint(x: 37, y: 9))
            shard.addLine(to: CGPoint(x: 45, y: 13))
            shard.addLine(to: CGPoint(x: 11, y: 14))
            shard.close()
            UIColor(red: 0.56, green: 0.34, blue: 0.17, alpha: 1).setFill()
            shard.fill()
            cg.saveGState()
            shard.addClip()
            for index in 0..<5 {
                let y = CGFloat(index) * 3 + 3
                cg.setStrokeColor((index.isMultiple(of: 2)
                    ? UIColor(red: 0.88, green: 0.67, blue: 0.40, alpha: 0.8)
                    : UIColor(red: 0.24, green: 0.12, blue: 0.05, alpha: 0.7)).cgColor)
                cg.setLineWidth(0.9)
                cg.move(to: CGPoint(x: 3, y: y + 2))
                cg.addLine(to: CGPoint(x: 44, y: y - 3))
                cg.strokePath()
            }
            cg.restoreGState()
        }
    }

    static func makeWoodChipSprite() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 14), format: format)
        return renderer.image { context in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 2, y: 8))
            path.addLine(to: CGPoint(x: 8, y: 4))
            path.addLine(to: CGPoint(x: 35, y: 2))
            path.addLine(to: CGPoint(x: 39, y: 6))
            path.addLine(to: CGPoint(x: 33, y: 10))
            path.addLine(to: CGPoint(x: 5, y: 12))
            path.close()
            UIColor(red: 0.68, green: 0.46, blue: 0.25, alpha: 1).setFill()
            path.fill()
            context.cgContext.saveGState()
            path.addClip()
            for i in 0..<12 {
                let y = CGFloat(i) * 1.15
                context.cgContext.setStrokeColor((i % 3 == 0
                    ? UIColor(red: 0.86, green: 0.67, blue: 0.42, alpha: 0.75)
                    : UIColor(red: 0.29, green: 0.18, blue: 0.09, alpha: 0.48)).cgColor)
                context.cgContext.setLineWidth(i % 3 == 0 ? 0.55 : 0.8)
                context.cgContext.move(to: CGPoint(x: 0, y: y + 3))
                context.cgContext.addCurve(
                    to: CGPoint(x: 40, y: y - 1),
                    control1: CGPoint(x: 12, y: y),
                    control2: CGPoint(x: 26, y: y + 2)
                )
                context.cgContext.strokePath()
            }
            context.cgContext.restoreGState()
            context.cgContext.setStrokeColor(UIColor(red: 0.25, green: 0.14, blue: 0.07, alpha: 0.9).cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.move(to: CGPoint(x: 6, y: 8))
            context.cgContext.addLine(to: CGPoint(x: 34, y: 5))
            context.cgContext.move(to: CGPoint(x: 13, y: 7))
            context.cgContext.addLine(to: CGPoint(x: 18, y: 4))
            context.cgContext.move(to: CGPoint(x: 23, y: 6))
            context.cgContext.addLine(to: CGPoint(x: 28, y: 3))
            context.cgContext.strokePath()
        }
    }

    // MARK: - 3D Spatial Layer Geometries

    /// Builds an inward-facing 360° cylinder with 1:1 un-stretched aspect ratio UVs
    /// (`uRepeat = 7.0` repeats the single non-mirrored cosine-blended period 7× around 360°).
    static func makePanoramicCylinder(
        radius: Float,
        bottomY: Float,
        topY: Float,
        radialSegments: Int = 144,
        uRepeat: Float = 7.0,
        texture: UIImage,
        transparent: Bool
    ) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []

        for i in 0...radialSegments {
            let frac = Float(i) / Float(radialSegments)
            // frac = 0.5 -> theta = 0 (dead ahead at -Z)
            let theta = (frac - 0.5) * 2.0 * .pi
            // Center dead-ahead (theta = 0) at u = 0.55 (the clean non-blended interior of the strip)
            let u = (frac - 0.5) * uRepeat + 0.55 + uRepeat
            let sx = sin(theta)
            let cz = -cos(theta)
            let px = sx * radius
            let pz = cz * radius
            let inwardNormal = SCNVector3(-sx, 0, -cz)

            // Bottom vertex (t = 0 -> uv.y = 1.0)
            vertices.append(SCNVector3(px, bottomY, pz))
            normals.append(inwardNormal)
            uvs.append(CGPoint(x: CGFloat(u), y: 1.0))

            // Top vertex (t = 1 -> uv.y = 0.0)
            vertices.append(SCNVector3(px, topY, pz))
            normals.append(inwardNormal)
            uvs.append(CGPoint(x: CGFloat(u), y: 0.0))

            if i < radialSegments {
                let base = UInt32(i * 2)
                indices += [base, base + 2, base + 1, base + 1, base + 2, base + 3]
            }
        }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = texture
        material.isDoubleSided = true
        material.writesToDepthBuffer = !transparent
        material.readsFromDepthBuffer = true
        if transparent {
            material.transparencyMode = .aOne
        }
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clampToBorder
        smoothTextureSampling(material.diffuse)
        geometry.materials = [material]
        return geometry
    }

    /// Builds an inward-facing 360° sky sphere with 1:1 un-stretched cloud UVs (`uRepeat = 7.0`).
    static func makeSkyDome(radius: Float, uRepeat: Float = 7.0, texture: UIImage) -> SCNGeometry {
        let lonSegments = 120
        let latSegments = 48
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []

        for lat in 0...latSegments {
            let v = Float(lat) / Float(latSegments) // 0 = zenith (+Y), 1 = nadir (-Y)
            let phi = v * .pi
            let sinPhi = sin(phi)
            let cosPhi = cos(phi)

            for lon in 0...lonSegments {
                let frac = Float(lon) / Float(lonSegments)
                let theta = (frac - 0.5) * 2.0 * .pi
                let u = (frac - 0.5) * uRepeat + 0.55 + uRepeat
                let nx = sinPhi * sin(theta)
                let ny = cosPhi
                let nz = -sinPhi * cos(theta)

                vertices.append(SCNVector3(nx * radius, ny * radius, nz * radius))
                normals.append(SCNVector3(-nx, -ny, -nz))
                uvs.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))

                if lat < latSegments && lon < lonSegments {
                    let row1 = UInt32(lat * (lonSegments + 1) + lon)
                    let row2 = row1 + UInt32(lonSegments + 1)
                    indices += [row1, row2, row1 + 1, row1 + 1, row2, row2 + 1]
                }
            }
        }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = texture
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clampToBorder
        smoothTextureSampling(material.diffuse)
        geometry.materials = [material]
        return geometry
    }

    /// Builds the unified 3D huma terrain floor that stays flat at `soilY` in the interactive
    /// clearing and rises gently at the horizon rim to meet the mountain valley seamlessly.
    static func makeTerrainMesh(span: Float = 24.0, steps: Int = 80, soilY: Float = 0.038, texture: UIImage) -> (geometry: SCNGeometry, material: SCNMaterial) {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []

        for z in 0...steps {
            for x in 0...steps {
                let px = (Float(x) / Float(steps) - 0.5) * span
                let pz = (Float(z) / Float(steps) - 0.5) * span
                let radius = sqrt(px * px + pz * pz)

                // Central 3.6m clearing is level at soilY for trees, roots, and shadows
                let edgeBlend = min(1.0, max(0.0, (radius - 3.4) / 4.8))
                let undulation = sin(px * 0.70) * cos(pz * 0.60) * 0.04
                let rimLift = min(1.0, max(0.0, (radius - 7.5) / 4.0)) * 0.16
                let py = soilY + edgeBlend * undulation + rimLift

                vertices.append(SCNVector3(px, py, pz))
                normals.append(SCNVector3(0, 1, 0))
                // High-density UV mapping: 1 tile per 1.65m for crisp, tactile Baduy earth clods & pebbles
                uvs.append(CGPoint(x: CGFloat(px / 1.65 + 0.5), y: CGFloat(pz / 1.65 + 0.5)))

                if x < steps && z < steps {
                    let a = UInt32(z * (steps + 1) + x)
                    let b = a + UInt32(steps + 1)
                    indices += [a, b, a + 1, a + 1, b, b + 1]
                }
            }
        }

        let material = SCNMaterial()
        material.name = "humaSoil"
        material.lightingModel = .constant
        material.diffuse.contents = texture
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.multiply.contents = UIColor.white
        material.isDoubleSided = true
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = true
        // Circular soft feather: perfectly rounds the terrain and smoothly blends the edge into the horizon
        material.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float r = length(_surface.position.xz);
        float edgeFade = 1.0 - smoothstep(10.0, 11.8, r);
        _output.color.a *= edgeFade;
        """]
        smoothTextureSampling(material.diffuse)

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return (geometry, material)
    }

    static func smoothTextureSampling(_ property: SCNMaterialProperty) {
        property.minificationFilter = .linear
        property.magnificationFilter = .linear
        property.mipFilter = .linear
        property.maxAnisotropy = 8
    }
}
