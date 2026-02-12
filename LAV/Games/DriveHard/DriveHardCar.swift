import SceneKit

enum DriveHardCar {

    // MARK: - Player Car (Red Ferrari-style)

    static func createPlayerCar() -> SCNNode {
        let group = SCNNode()

        // Materials — exact web hex colors
        let red = toonMaterial(color: UIColor(red: 0xdd/255, green: 0x11/255, blue: 0x11/255, alpha: 1))       // 0xdd1111
        let darkRed = toonMaterial(color: UIColor(red: 0xaa/255, green: 0x00/255, blue: 0x00/255, alpha: 1))    // 0xaa0000
        let carbon = toonMaterial(color: UIColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1))     // 0x1a1a1a
        let chrome = toonMaterial(color: UIColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1))     // dark
        let glass = toonMaterial(color: UIColor(red: 0x44/255, green: 0x88/255, blue: 0xcc/255, alpha: 0.55))   // 0x4488cc
        let archMat = toonMaterial(color: UIColor(red: 0x11/255, green: 0x11/255, blue: 0x11/255, alpha: 1))    // 0x111111
        let doorLineMat = toonMaterial(color: UIColor(red: 0xbb/255, green: 0x00/255, blue: 0x00/255, alpha: 1)) // 0xbb0000

        // ── Main body — low, wide, aggressive ──
        let body = boxNode(w: 1.8, h: 0.45, d: 4.0, chamfer: 0.12, material: red)
        body.position = SCNVector3(0, 0.45, 0)
        group.addChildNode(body)

        // Front section — tapered lower
        let frontLower = boxNode(w: 1.7, h: 0.2, d: 0.8, chamfer: 0.08, material: red)
        frontLower.position = SCNVector3(0, 0.32, -2.0)
        group.addChildNode(frontLower)

        // Nose
        let nose = boxNode(w: 1.5, h: 0.15, d: 0.5, chamfer: 0.06, material: red)
        nose.position = SCNVector3(0, 0.28, -2.35)
        group.addChildNode(nose)

        // ── Front grille (dark mesh + chrome slats) ──
        let grille = boxNode(w: 1.1, h: 0.2, d: 0.06, chamfer: 0.03, material: carbon)
        grille.position = SCNVector3(0, 0.32, -2.58)
        group.addChildNode(grille)
        for i in -3...3 {
            let slat = boxNode(w: 0.03, h: 0.16, d: 0.04, chamfer: 0, material: chrome)
            slat.position = SCNVector3(Float(i) * 0.14, 0.32, -2.6)
            group.addChildNode(slat)
        }

        // ── Front splitter + canards ──
        let splitter = boxNode(w: 1.9, h: 0.06, d: 0.4, chamfer: 0.02, material: carbon)
        splitter.position = SCNVector3(0, 0.2, -2.25)
        group.addChildNode(splitter)
        for x: Float in [-0.85, 0.85] {
            let canard = boxNode(w: 0.12, h: 0.04, d: 0.35, chamfer: 0.02, material: carbon)
            canard.position = SCNVector3(x, 0.25, -2.3)
            group.addChildNode(canard)
        }

        // ── Hood with center crease + scoops ──
        let hood = boxNode(w: 1.45, h: 0.06, d: 1.6, chamfer: 0.02, material: red)
        hood.position = SCNVector3(0, 0.7, -1.2)
        group.addChildNode(hood)
        let hoodLine = boxNode(w: 0.02, h: 0.01, d: 1.5, chamfer: 0, material: darkRed)
        hoodLine.position = SCNVector3(0, 0.74, -1.2)
        group.addChildNode(hoodLine)
        for x: Float in [-0.38, 0.38] {
            let scoop = boxNode(w: 0.28, h: 0.12, d: 0.5, chamfer: 0.03, material: carbon)
            scoop.position = SCNVector3(x, 0.73, -1.2)
            group.addChildNode(scoop)
        }

        // ── Cabin — low, set back ──
        let cabin = boxNode(w: 1.35, h: 0.45, d: 1.6, chamfer: 0.15, material: darkRed)
        cabin.position = SCNVector3(0, 0.88, 0.1)
        group.addChildNode(cabin)

        // A-pillars
        for x: Float in [-0.62, 0.62] {
            let pillar = boxNode(w: 0.06, h: 0.38, d: 0.7, chamfer: 0, material: carbon)
            pillar.position = SCNVector3(x, 0.87, -0.3)
            pillar.eulerAngles.x = -0.22
            group.addChildNode(pillar)
        }

        // ── Windows: windshield, rear, sides ──
        let ws = planeNode(w: 1.2, h: 0.42, material: glass)
        ws.position = SCNVector3(0, 0.92, -0.7)
        ws.eulerAngles.x = -0.35
        group.addChildNode(ws)

        let rw = planeNode(w: 1.1, h: 0.35, material: glass)
        rw.position = SCNVector3(0, 0.92, 0.92)
        rw.eulerAngles.x = 0.35
        group.addChildNode(rw)

        for x: Float in [-0.69, 0.69] {
            let sw = planeNode(w: 1.3, h: 0.35, material: glass)
            sw.position = SCNVector3(x, 0.9, 0.1)
            sw.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
            group.addChildNode(sw)
        }

        // ── Fender arches (wheel well lips) ──
        let archGeo = SCNTorus(ringRadius: 0.42, pipeRadius: 0.06)
        archGeo.firstMaterial = archMat
        for (x, y, z) in [(-0.85, 0.38, -1.1), (0.85, 0.38, -1.1), (-0.85, 0.38, 1.1), (0.85, 0.38, 1.1)] as [(Float, Float, Float)] {
            let arch = SCNNode(geometry: archGeo)
            arch.position = SCNVector3(x, y, z)
            arch.eulerAngles.z = .pi / 2
            group.addChildNode(arch)
        }

        // ── Side skirts ──
        for x: Float in [-0.93, 0.93] {
            let skirt = boxNode(w: 0.08, h: 0.15, d: 3.5, chamfer: 0.02, material: carbon)
            skirt.position = SCNVector3(x, 0.25, 0)
            group.addChildNode(skirt)
        }

        // ── Side air intakes with chrome slats ──
        for x: Float in [-0.92, 0.92] {
            let intake = boxNode(w: 0.05, h: 0.22, d: 0.6, chamfer: 0.02, material: carbon)
            intake.position = SCNVector3(x, 0.42, -0.5)
            group.addChildNode(intake)
            for i in 0..<3 {
                let iSlat = boxNode(w: 0.02, h: 0.01, d: 0.55, chamfer: 0, material: chrome)
                iSlat.position = SCNVector3(x, 0.34 + Float(i) * 0.06, -0.5)
                group.addChildNode(iSlat)
            }
        }

        // ── Door lines ──
        for x: Float in [-0.89, 0.89] {
            let dLine = boxNode(w: 0.01, h: 0.28, d: 2.0, chamfer: 0, material: doorLineMat)
            dLine.position = SCNVector3(x, 0.5, 0.1)
            group.addChildNode(dLine)
        }

        // ── Rear haunches (wider rear fenders) ──
        for x: Float in [-0.82, 0.82] {
            let haunch = boxNode(w: 0.25, h: 0.38, d: 1.0, chamfer: 0.08, material: red)
            haunch.position = SCNVector3(x * 1.05, 0.45, 1.0)
            group.addChildNode(haunch)
        }

        // ── Rear diffuser with fins ──
        let diffuser = boxNode(w: 1.7, h: 0.18, d: 0.35, chamfer: 0.03, material: carbon)
        diffuser.position = SCNVector3(0, 0.22, 1.95)
        group.addChildNode(diffuser)
        for i in -3...3 {
            let fin = boxNode(w: 0.03, h: 0.14, d: 0.3, chamfer: 0, material: carbon)
            fin.position = SCNVector3(Float(i) * 0.22, 0.22, 1.95)
            group.addChildNode(fin)
        }

        // ── Quad exhaust tips + glow ──
        let exGeo = SCNCylinder(radius: 0.06, height: 0.18)
        let exMat = toonMaterial(color: UIColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1))
        exGeo.firstMaterial = exMat
        for x: Float in [-0.4, -0.15, 0.15, 0.4] {
            let ex = SCNNode(geometry: exGeo)
            ex.position = SCNVector3(x, 0.24, 2.05)
            ex.eulerAngles.x = .pi / 2
            group.addChildNode(ex)

            let glowGeo = SCNSphere(radius: 0.04)
            glowGeo.firstMaterial = emissiveMaterial(color: UIColor(red: 1, green: 0.27, blue: 0, alpha: 0.7))
            let glow = SCNNode(geometry: glowGeo)
            glow.position = SCNVector3(x, 0.24, 2.1)
            group.addChildNode(glow)
        }

        // ── Rear spoiler (wing + endplates + stalks) ──
        let spoilerWing = boxNode(w: 1.6, h: 0.06, d: 0.3, chamfer: 0.02, material: carbon)
        spoilerWing.position = SCNVector3(0, 1.05, 1.55)
        group.addChildNode(spoilerWing)
        // Endplates
        for x: Float in [-0.75, 0.75] {
            let ep = boxNode(w: 0.05, h: 0.22, d: 0.35, chamfer: 0.01, material: carbon)
            ep.position = SCNVector3(x, 0.95, 1.55)
            group.addChildNode(ep)
        }
        // Stalks
        for x: Float in [-0.5, 0.5] {
            let stalk = boxNode(w: 0.04, h: 0.22, d: 0.04, chamfer: 0, material: carbon)
            stalk.position = SCNVector3(x, 0.86, 1.4)
            group.addChildNode(stalk)
        }

        // ── Side mirrors ──
        for x: Float in [-0.92, 0.92] {
            let arm = boxNode(w: 0.22, h: 0.03, d: 0.03, chamfer: 0, material: carbon)
            arm.position = SCNVector3(x + (x > 0 ? 0.1 : -0.1), 0.73, -0.5)
            group.addChildNode(arm)
            let mb = boxNode(w: 0.14, h: 0.1, d: 0.08, chamfer: 0.02, material: carbon)
            mb.position = SCNVector3(x + (x > 0 ? 0.22 : -0.22), 0.73, -0.5)
            group.addChildNode(mb)
        }

        // ── LED headlights with chrome rings ──
        let ledMat = emissiveMaterial(color: .white)
        let ledStrip = boxNode(w: 1.3, h: 0.05, d: 0.05, chamfer: 0.01, material: ledMat)
        ledStrip.position = SCNVector3(0, 0.38, -2.55)
        group.addChildNode(ledStrip)

        let ringGeo = SCNTorus(ringRadius: 0.08, pipeRadius: 0.015)
        ringGeo.firstMaterial = chrome
        for x: Float in [-0.45, -0.15, 0.15, 0.45] {
            let hl = SCNNode(geometry: SCNSphere(radius: 0.07))
            hl.geometry?.firstMaterial = emissiveMaterial(color: UIColor(red: 1, green: 1, blue: 0.87, alpha: 1))
            hl.position = SCNVector3(x, 0.38, -2.57)
            group.addChildNode(hl)

            let ring = SCNNode(geometry: ringGeo)
            ring.position = SCNVector3(x, 0.38, -2.57)
            group.addChildNode(ring)
        }

        // Headlight glow plane
        let hlGlow = planeNode(w: 1.4, h: 0.3, material: emissiveMaterial(color: UIColor(red: 1, green: 1, blue: 0.87, alpha: 0.35)))
        hlGlow.geometry?.firstMaterial?.isDoubleSided = true
        hlGlow.position = SCNVector3(0, 0.38, -2.65)
        group.addChildNode(hlGlow)

        // ── LED taillights ──
        let tailStrip = boxNode(w: 1.5, h: 0.05, d: 0.05, chamfer: 0.01, material: emissiveMaterial(color: UIColor(red: 1, green: 0.07, blue: 0.07, alpha: 1)))
        tailStrip.position = SCNVector3(0, 0.5, 1.92)
        group.addChildNode(tailStrip)
        for x: Float in [-0.55, -0.25, 0.25, 0.55] {
            let tl = SCNNode(geometry: SCNSphere(radius: 0.06))
            tl.geometry?.firstMaterial = emissiveMaterial(color: UIColor(red: 1, green: 0.13, blue: 0, alpha: 1))
            tl.position = SCNVector3(x, 0.5, 1.94)
            group.addChildNode(tl)
        }

        // ── Wheels ──
        addWheels(to: group, positions: [
            SCNVector3(-0.85, 0.3, -1.1),
            SCNVector3(0.85, 0.3, -1.1),
            SCNVector3(-0.85, 0.3, 1.1),
            SCNVector3(0.85, 0.3, 1.1),
        ])

        return group
    }

    // MARK: - Obstacle Cars

    static func createObstacleCar(type: String) -> SCNNode {
        let group = SCNNode()
        group.name = type

        let cfg = ObstacleConfig.config(for: type)
        let mat = toonMaterial(color: cfg.color)
        let chromeMat = toonMaterial(color: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        let glass = toonMaterial(color: UIColor(red: 0.27, green: 0.53, blue: 0.8, alpha: 0.5))

        // Main body
        let body = boxNode(w: cfg.bodyWidth, h: cfg.bodyHeight, d: cfg.bodyDepth, chamfer: 0.12, material: mat)
        body.position = SCNVector3(0, cfg.centerY, 0)
        group.addChildNode(body)

        // Bumpers
        let fBumper = boxNode(w: cfg.bodyWidth + 0.05, h: 0.14, d: 0.14, chamfer: 0.04, material: chromeMat)
        fBumper.position = SCNVector3(0, 0.28, -(cfg.bodyDepth / 2 + 0.05))
        group.addChildNode(fBumper)

        let rBumper = boxNode(w: cfg.bodyWidth + 0.05, h: 0.14, d: 0.14, chamfer: 0.04, material: chromeMat)
        rBumper.position = SCNVector3(0, 0.28, cfg.bodyDepth / 2 + 0.05)
        group.addChildNode(rBumper)

        // Headlights
        let hlMat = emissiveMaterial(color: UIColor(red: 1, green: 1, blue: 0.8, alpha: 1))
        for x: Float in [-cfg.bodyWidth * 0.35, cfg.bodyWidth * 0.35] {
            let hl = SCNNode(geometry: SCNSphere(radius: 0.08))
            hl.geometry?.firstMaterial = hlMat
            hl.position = SCNVector3(x, cfg.centerY * 0.85, -(cfg.bodyDepth / 2 + 0.02))
            group.addChildNode(hl)
        }

        // Type-specific details
        switch type {
        case "taxi":
            let cabinMat = toonMaterial(color: UIColor(red: 0.33, green: 0.87, blue: 0.67, alpha: 1))
            let cabinNode = boxNode(w: cfg.cabinWidth, h: cfg.cabinHeight, d: cfg.cabinDepth, chamfer: 0.1, material: cabinMat)
            cabinNode.position = SCNVector3(0, 1.0, 0.1)
            group.addChildNode(cabinNode)

            for x: Float in [-0.61, 0.61] {
                let win = planeNode(w: 1.2, h: 0.38, material: glass)
                win.position = SCNVector3(x, 1.0, 0.1)
                win.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
                group.addChildNode(win)
            }

            let sign = boxNode(w: 0.4, h: 0.2, d: 0.2, chamfer: 0.05, material: emissiveMaterial(color: UIColor(red: 0.67, green: 1, blue: 0.87, alpha: 1)))
            sign.position = SCNVector3(0, 1.35, 0.1)
            group.addChildNode(sign)

        case "bus":
            let winSpacing: Float = 0.8
            for z in Swift.stride(from: Float(-1.2), through: 1.2, by: winSpacing) {
                for x: Float in [-0.91, 0.91] {
                    let win = planeNode(w: 0.5, h: 0.6, material: glass)
                    win.position = SCNVector3(x, 1.2, z)
                    win.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
                    group.addChildNode(win)
                }
            }
            let destSign = boxNode(w: 0.8, h: 0.25, d: 0.04, chamfer: 0.03, material: emissiveMaterial(color: UIColor(red: 1, green: 0.53, blue: 0, alpha: 1)))
            destSign.position = SCNVector3(0, cfg.centerY + cfg.bodyHeight / 2, -(cfg.bodyDepth / 2 + 0.02))
            group.addChildNode(destSign)

        case "truck":
            let roof = boxNode(w: 1.3, h: 0.5, d: 1.0, chamfer: 0.08, material: mat)
            roof.position = SCNVector3(0, 1.3, -0.8)
            group.addChildNode(roof)

            for x: Float in [-0.76, 0.76] {
                let win = planeNode(w: 0.8, h: 0.4, material: glass)
                win.position = SCNVector3(x, 1.1, -0.8)
                win.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
                group.addChildNode(win)
            }

        case "sports":
            let cabinMat = toonMaterial(color: UIColor(red: 1, green: 0.67, blue: 0.27, alpha: 1))
            let cabinNode = boxNode(w: cfg.cabinWidth, h: cfg.cabinHeight, d: cfg.cabinDepth, chamfer: 0.1, material: cabinMat)
            cabinNode.position = SCNVector3(0, 0.85, 0.1)
            group.addChildNode(cabinNode)

            for x: Float in [-0.56, 0.56] {
                let win = planeNode(w: 1.0, h: 0.3, material: glass)
                win.position = SCNVector3(x, 0.85, 0.1)
                win.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
                group.addChildNode(win)
            }

            let sp = boxNode(w: 1.2, h: 0.06, d: 0.3, chamfer: 0.02, material: toonMaterial(color: UIColor(red: 0.8, green: 0.33, blue: 0, alpha: 1)))
            sp.position = SCNVector3(0, 0.85, 1.4)
            group.addChildNode(sp)

        case "van":
            for x: Float in [-0.81, 0.81] {
                for z: Float in [-0.5, 0.5] {
                    let win = planeNode(w: 0.6, h: 0.5, material: glass)
                    win.position = SCNVector3(x, 1.0, z)
                    win.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
                    group.addChildNode(win)
                }
            }
            let rack = boxNode(w: 1.2, h: 0.04, d: 2.0, chamfer: 0.01, material: chromeMat)
            rack.position = SCNVector3(0, cfg.centerY + cfg.bodyHeight / 2 + 0.05, 0)
            group.addChildNode(rack)

        case "ambulance":
            let stripeMat = toonMaterial(color: UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
            let stripe = boxNode(w: 1.62, h: 0.22, d: 3.22, chamfer: 0.02, material: stripeMat)
            stripe.position.y = 0.75
            group.addChildNode(stripe)

            let roofLight = SCNNode(geometry: SCNSphere(radius: 0.15))
            roofLight.geometry?.firstMaterial = emissiveMaterial(color: .red)
            roofLight.position = SCNVector3(0, 1.45, -0.5)
            group.addChildNode(roofLight)

            for x: Float in [-0.81, 0.81] {
                let win = planeNode(w: 1.5, h: 0.5, material: glass)
                win.position = SCNVector3(x, 1.0, 0)
                win.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
                group.addChildNode(win)
            }

        default:
            break
        }

        // Taillights
        let tlMat = emissiveMaterial(color: UIColor(red: 1, green: 0.13, blue: 0, alpha: 1))
        for x: Float in [-0.4, 0.4] {
            let tl = SCNNode(geometry: SCNSphere(radius: 0.08))
            tl.geometry?.firstMaterial = tlMat
            tl.position = SCNVector3(x, cfg.centerY, cfg.bodyDepth / 2 + 0.02)
            group.addChildNode(tl)
        }

        // Wheels
        addWheels(to: group, positions: [
            SCNVector3(-cfg.bodyWidth * 0.45, 0.28, -cfg.bodyDepth * 0.35),
            SCNVector3(cfg.bodyWidth * 0.45, 0.28, -cfg.bodyDepth * 0.35),
            SCNVector3(-cfg.bodyWidth * 0.45, 0.28, cfg.bodyDepth * 0.35),
            SCNVector3(cfg.bodyWidth * 0.45, 0.28, cfg.bodyDepth * 0.35),
        ])

        // Store collision box
        let hw = cfg.bodyWidth * 0.5
        let hd = cfg.bodyDepth * 0.5
        group.setValue(NSValue(scnVector3: SCNVector3(hw, cfg.centerY + cfg.bodyHeight * 0.5 + 0.2, hd)), forKey: "halfExtents")

        return group
    }

    // MARK: - Helpers

    private static func addWheels(to group: SCNNode, positions: [SCNVector3]) {
        let wheelGeo = SCNCylinder(radius: 0.32, height: 0.26)
        let wheelMat = toonMaterial(color: UIColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1))
        wheelGeo.firstMaterial = wheelMat

        let hubGeo = SCNCylinder(radius: 0.16, height: 0.28)
        let hubMat = toonMaterial(color: UIColor(red: 0x22/255, green: 0x22/255, blue: 0x22/255, alpha: 1))
        hubGeo.firstMaterial = hubMat

        let rimGeo = SCNTorus(ringRadius: 0.24, pipeRadius: 0.025)
        let rimMat = toonMaterial(color: UIColor(red: 0x22/255, green: 0x22/255, blue: 0x22/255, alpha: 1))
        rimGeo.firstMaterial = rimMat

        for pos in positions {
            let wheel = SCNNode(geometry: wheelGeo)
            wheel.position = pos
            wheel.eulerAngles.z = .pi / 2
            group.addChildNode(wheel)

            let hub = SCNNode(geometry: hubGeo)
            hub.position = pos
            hub.eulerAngles.z = .pi / 2
            group.addChildNode(hub)

            let rim = SCNNode(geometry: rimGeo)
            rim.position = pos
            rim.eulerAngles.z = .pi / 2
            group.addChildNode(rim)
        }
    }

    static func boxNode(w: Float, h: Float, d: Float, chamfer: CGFloat, material: SCNMaterial) -> SCNNode {
        let geo = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: chamfer)
        geo.firstMaterial = material
        return SCNNode(geometry: geo)
    }

    static func planeNode(w: Float, h: Float, material: SCNMaterial) -> SCNNode {
        let geo = SCNPlane(width: CGFloat(w), height: CGFloat(h))
        geo.firstMaterial = material
        return SCNNode(geometry: geo)
    }

    // Toon/cel-shading fragment modifier — quantizes lighting into 4 discrete steps
    // matching Three.js MeshToonMaterial with gradientMap [100, 170, 220, 255]
    private static let toonShaderModifier: String = """
    #pragma body
    // Get luminance of the lit fragment
    float lum = dot(_output.color.rgb, float3(0.299, 0.587, 0.114));
    // 4-step quantization matching web gradient map
    float step_val;
    if (lum > 0.75) { step_val = 1.0; }
    else if (lum > 0.50) { step_val = 0.86; }
    else if (lum > 0.25) { step_val = 0.67; }
    else { step_val = 0.39; }
    // Apply quantized lighting while preserving color hue
    float scale = min(step_val / max(lum, 0.001), 1.0);
    _output.color.rgb *= scale;
    """

    static func toonMaterial(color: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .blinn
        mat.shaderModifiers = [.fragment: toonShaderModifier]
        return mat
    }

    static func emissiveMaterial(color: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.lightingModel = .constant
        return mat
    }
}
