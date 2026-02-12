import SceneKit

// MARK: - Wall Data

struct WallData {
    let group: SCNNode
    let idx: Int
    var passed: Bool
    let gapX: Float
    let gapY: Float
    let palette: WConst.Palette
    let toonMat: SCNMaterial
    var nearMissed: Bool = false
}

// MARK: - Tunnel Builder

enum WarpTunnel {

    // MARK: - Box Part Helper

    /// Creates an outlined box pair: [outlineNode, meshNode]
    static func boxPart(
        w: Float, h: Float,
        x: Float, y: Float,
        toonMat: SCNMaterial,
        outMat: SCNMaterial
    ) -> [SCNNode] {
        let geo = SCNBox(width: CGFloat(w), height: CGFloat(h),
                         length: CGFloat(WConst.wallThick), chamferRadius: 0)
        geo.firstMaterial = toonMat
        let mesh = SCNNode(geometry: geo)
        mesh.position = SCNVector3(x, y, 0)

        let pad = WConst.outlinePad
        let oGeo = SCNBox(width: CGFloat(w + pad), height: CGFloat(h + pad),
                          length: CGFloat(WConst.wallThick + pad), chamferRadius: 0)
        oGeo.firstMaterial = outMat
        let outline = SCNNode(geometry: oGeo)
        outline.position = SCNVector3(x, y, 0)

        return [outline, mesh]
    }

    // MARK: - Wall Types (matching web exactly)

    /// Horizontal slit — gap at gapY with gapH height
    static func wallHSlit(gapY: Float, gapH: Float,
                          tMat: SCNMaterial, oMat: SCNMaterial) -> [SCNNode] {
        var parts: [SCNNode] = []
        let W = WConst.arenaW + 1
        let H = WConst.arenaH + 1

        let botH = (gapY - gapH / 2) + H / 2
        if botH > 0.15 {
            parts.append(contentsOf: boxPart(w: W, h: botH,
                                              x: 0, y: -H / 2 + botH / 2,
                                              toonMat: tMat, outMat: oMat))
        }

        let topH = H / 2 - (gapY + gapH / 2)
        if topH > 0.15 {
            parts.append(contentsOf: boxPart(w: W, h: topH,
                                              x: 0, y: H / 2 - topH / 2,
                                              toonMat: tMat, outMat: oMat))
        }

        return parts
    }

    /// Vertical slit — gap at gapX with gapW width
    static func wallVSlit(gapX: Float, gapW: Float,
                          tMat: SCNMaterial, oMat: SCNMaterial) -> [SCNNode] {
        var parts: [SCNNode] = []
        let W = WConst.arenaW + 1
        let H = WConst.arenaH + 1

        let leftW = (gapX - gapW / 2) + W / 2
        if leftW > 0.15 {
            parts.append(contentsOf: boxPart(w: leftW, h: H,
                                              x: -W / 2 + leftW / 2, y: 0,
                                              toonMat: tMat, outMat: oMat))
        }

        let rightW = W / 2 - (gapX + gapW / 2)
        if rightW > 0.15 {
            parts.append(contentsOf: boxPart(w: rightW, h: H,
                                              x: W / 2 - rightW / 2, y: 0,
                                              toonMat: tMat, outMat: oMat))
        }

        return parts
    }

    /// L-shaped gap — horizontal bar + vertical side piece
    static func wallLShape(cx: Float, cy: Float, gapS: Float,
                           tMat: SCNMaterial, oMat: SCNMaterial) -> [SCNNode] {
        var parts: [SCNNode] = []
        let W = WConst.arenaW + 1
        let H = WConst.arenaH + 1

        let barH = H - gapS
        let barY: Float = cy > 0 ? -H / 2 + barH / 2 : H / 2 - barH / 2
        parts.append(contentsOf: boxPart(w: W, h: barH,
                                          x: 0, y: barY,
                                          toonMat: tMat, outMat: oMat))

        let sideW = W - gapS
        let sideX: Float = cx > 0 ? -W / 2 + sideW / 2 : W / 2 - sideW / 2
        let sideY: Float = cy > 0 ? H / 2 - gapS / 2 : -H / 2 + gapS / 2
        parts.append(contentsOf: boxPart(w: sideW, h: gapS,
                                          x: sideX, y: sideY,
                                          toonMat: tMat, outMat: oMat))

        return parts
    }

    /// Dual horizontal slits — three bars with two gaps
    static func wallDualHSlit(y1: Float, y2: Float, gapH: Float,
                              tMat: SCNMaterial, oMat: SCNMaterial) -> [SCNNode] {
        var parts: [SCNNode] = []
        let W = WConst.arenaW + 1
        let H = WConst.arenaH + 1

        let bH = (y1 - gapH / 2) + H / 2
        if bH > 0.15 {
            parts.append(contentsOf: boxPart(w: W, h: bH,
                                              x: 0, y: -H / 2 + bH / 2,
                                              toonMat: tMat, outMat: oMat))
        }

        let midBot = y1 + gapH / 2
        let midTop = y2 - gapH / 2
        let mH = midTop - midBot
        if mH > 0.15 {
            parts.append(contentsOf: boxPart(w: W, h: mH,
                                              x: 0, y: (midBot + midTop) / 2,
                                              toonMat: tMat, outMat: oMat))
        }

        let tH = H / 2 - (y2 + gapH / 2)
        if tH > 0.15 {
            parts.append(contentsOf: boxPart(w: W, h: tH,
                                              x: 0, y: H / 2 - tH / 2,
                                              toonMat: tMat, outMat: oMat))
        }

        return parts
    }

    // MARK: - Obstacle (red box within gap at higher difficulty)

    static func addObstacle(gx: Float, gy: Float, gapSize: Float,
                            obsTMat: SCNMaterial, oMat: SCNMaterial) -> [SCNNode] {
        let oW = 0.6 + Float.random(in: 0...0.8)
        let oH = 0.5 + Float.random(in: 0...0.6)
        let offX = (Float.random(in: 0...1) - 0.5) * gapSize * 0.3
        let offY = (Float.random(in: 0...1) - 0.5) * gapSize * 0.3
        return boxPart(w: oW, h: oH,
                       x: gx + offX, y: gy + offY,
                       toonMat: obsTMat, outMat: oMat)
    }

    // MARK: - Wall Generator

    static func generateWall(
        idx: Int, z: Float,
        prevGapX: Float, prevGapY: Float,
        difficulty: Float,
        palette: WConst.Palette
    ) -> WallData {
        let d = difficulty
        let gapSize = WConst.getGapSize(difficulty: d)

        let outMat = WarpShip.outlineMaterial()
        let tMat = WarpShip.toonMaterial(color: WConst.color(palette.base))
        tMat.emission.contents = WConst.color(palette.base)
        tMat.emission.intensity = 0.15
        let obsTMat = WarpShip.toonMaterial(color: WConst.color(0xff3344))
        obsTMat.emission.contents = WConst.color(0xff3344)
        obsTMat.emission.intensity = 0.2

        // Random gap position, constrained by previous wall
        let halfW = WConst.arenaW / 2 - gapSize / 2 - 0.3
        let halfH = WConst.arenaH / 2 - gapSize / 2 - 0.3
        var gapX = (Float.random(in: 0...1) - 0.5) * halfW * 2
        var gapY = (Float.random(in: 0...1) - 0.5) * halfH * 2

        // Constrain shift from previous wall
        gapX = max(prevGapX - WConst.maxGapShift, min(prevGapX + WConst.maxGapShift, gapX))
        gapY = max(prevGapY - WConst.maxGapShift, min(prevGapY + WConst.maxGapShift, gapY))
        gapX = max(-halfW, min(halfW, gapX))
        gapY = max(-halfH, min(halfH, gapY))

        var parts: [SCNNode] = []

        // Wall type selection based on difficulty tiers (matching web free play logic)
        let roll = Float.random(in: 0...1)

        if d < 0.15 {
            // Easy: only H-slit or V-slit
            parts = roll < 0.5
                ? wallHSlit(gapY: gapY, gapH: gapSize, tMat: tMat, oMat: outMat)
                : wallVSlit(gapX: gapX, gapW: gapSize, tMat: tMat, oMat: outMat)

        } else if d < 0.4 {
            // Medium: add L-shapes
            if roll < 0.35 {
                parts = wallHSlit(gapY: gapY, gapH: gapSize, tMat: tMat, oMat: outMat)
            } else if roll < 0.65 {
                parts = wallVSlit(gapX: gapX, gapW: gapSize, tMat: tMat, oMat: outMat)
            } else {
                parts = wallLShape(cx: gapX > 0 ? 1 : -1, cy: gapY > 0 ? 1 : -1,
                                   gapS: gapSize, tMat: tMat, oMat: outMat)
            }

        } else if d < 0.65 {
            // Hard: obstacles appear
            if roll < 0.3 {
                parts = wallHSlit(gapY: gapY, gapH: gapSize, tMat: tMat, oMat: outMat)
                if Float.random(in: 0...1) < 0.4 {
                    parts.append(contentsOf: addObstacle(gx: gapX * 0.3, gy: gapY,
                                                          gapSize: gapSize, obsTMat: obsTMat, oMat: outMat))
                }
            } else if roll < 0.55 {
                parts = wallVSlit(gapX: gapX, gapW: gapSize, tMat: tMat, oMat: outMat)
                if Float.random(in: 0...1) < 0.4 {
                    parts.append(contentsOf: addObstacle(gx: gapX, gy: gapY * 0.3,
                                                          gapSize: gapSize, obsTMat: obsTMat, oMat: outMat))
                }
            } else if roll < 0.8 {
                parts = wallLShape(cx: gapX > 0 ? 1 : -1, cy: gapY > 0 ? 1 : -1,
                                   gapS: gapSize, tMat: tMat, oMat: outMat)
            } else {
                let hg = gapSize * 0.55
                let sep = gapSize * 0.8
                parts = wallDualHSlit(y1: gapY - sep / 2, y2: gapY + sep / 2,
                                      gapH: hg, tMat: tMat, oMat: outMat)
            }

        } else {
            // Expert: more obstacles, tighter
            if roll < 0.25 {
                parts = wallHSlit(gapY: gapY, gapH: gapSize, tMat: tMat, oMat: outMat)
                if Float.random(in: 0...1) < 0.6 {
                    parts.append(contentsOf: addObstacle(gx: gapX * 0.4, gy: gapY,
                                                          gapSize: gapSize, obsTMat: obsTMat, oMat: outMat))
                }
            } else if roll < 0.45 {
                parts = wallVSlit(gapX: gapX, gapW: gapSize, tMat: tMat, oMat: outMat)
                if Float.random(in: 0...1) < 0.6 {
                    parts.append(contentsOf: addObstacle(gx: gapX, gy: gapY * 0.4,
                                                          gapSize: gapSize, obsTMat: obsTMat, oMat: outMat))
                }
            } else if roll < 0.65 {
                parts = wallLShape(cx: gapX > 0 ? 1 : -1, cy: gapY > 0 ? 1 : -1,
                                   gapS: gapSize * 0.95, tMat: tMat, oMat: outMat)
            } else {
                let hg = gapSize * 0.5
                let sep = gapSize * 0.7
                parts = wallDualHSlit(y1: gapY - sep / 2, y2: gapY + sep / 2,
                                      gapH: hg, tMat: tMat, oMat: outMat)
                if Float.random(in: 0...1) < 0.5 {
                    parts.append(contentsOf: addObstacle(gx: gapX * 0.2, gy: gapY,
                                                          gapSize: hg, obsTMat: obsTMat, oMat: outMat))
                }
            }
        }

        let group = SCNNode()
        group.position.z = z
        for p in parts { group.addChildNode(p) }

        return WallData(group: group, idx: idx, passed: false,
                        gapX: gapX, gapY: gapY,
                        palette: palette, toonMat: tMat)
    }

    // MARK: - Tunnel Ring

    /// Creates a rectangular frame ring from thin bars (matches web EdgesGeometry box)
    static func createTunnelRing(index: Int) -> SCNNode {
        let w = WConst.arenaW + 0.4
        let h = WConst.arenaH + 0.4
        let geo = SCNBox(width: CGFloat(w), height: CGFloat(h), length: 0.015, chamferRadius: 0)

        // Wireframe-like appearance using edges geometry equivalent
        let colorIdx = index % WConst.ringColors.count
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.clear
        mat.emission.contents = WConst.color(WConst.ringColors[colorIdx])
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.fillMode = .lines

        geo.firstMaterial = mat

        let ring = SCNNode(geometry: geo)
        ring.position.z = Float(-index) * WConst.ringSpacing
        ring.opacity = 0.2

        return ring
    }
}
