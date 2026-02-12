import SceneKit

enum DriveHardRoad {

    // MARK: - Road Segment

    static func createRoadSegment() -> SCNNode {
        let group = SCNNode()
        let segLen = DHConst.roadSegmentLength

        // Road surface
        let roadGeo = SCNPlane(width: 10.5, height: CGFloat(segLen))
        roadGeo.firstMaterial = DriveHardCar.toonMaterial(color: UIColor(red: 0x5a/255.0, green: 0x5a/255.0, blue: 0x6a/255.0, alpha: 1)) // #5a5a6a
        let road = SCNNode(geometry: roadGeo)
        road.eulerAngles.x = -.pi / 2
        road.position.y = 0.01
        group.addChildNode(road)

        // Lane dashes
        let dashGeo = SCNBox(width: 0.12, height: 0.025, length: 1.8, chamferRadius: 0)
        let dashMat = DriveHardCar.emissiveMaterial(color: UIColor(white: 0.93, alpha: 1))
        dashGeo.firstMaterial = dashMat
        for side: Float in [-1, 1] {
            var z: Float = -segLen / 2 + 1
            while z < segLen / 2 {
                let dash = SCNNode(geometry: dashGeo)
                dash.position = SCNVector3(side * 1.6, 0.025, z)
                group.addChildNode(dash)
                z += 4
            }
        }

        // Yellow edge lines
        let edgeMat = DriveHardCar.emissiveMaterial(color: UIColor(red: 1, green: 0.8, blue: 0, alpha: 1))
        for x: Float in [-5.0, 5.0] {
            let edgeGeo = SCNBox(width: 0.12, height: 0.025, length: CGFloat(segLen), chamferRadius: 0)
            edgeGeo.firstMaterial = edgeMat
            let edge = SCNNode(geometry: edgeGeo)
            edge.position = SCNVector3(x, 0.025, 0)
            group.addChildNode(edge)
        }

        // Curbs (red/white)
        let curbGeo = SCNBox(width: 0.35, height: 0.12, length: 1.5, chamferRadius: 0)
        let curbWhite = DriveHardCar.toonMaterial(color: UIColor(white: 0.93, alpha: 1))
        let curbRed = DriveHardCar.toonMaterial(color: UIColor(red: 0.87, green: 0.2, blue: 0.2, alpha: 1))
        for x: Float in [-5.4, 5.4] {
            var z: Float = -segLen / 2
            while z < segLen / 2 {
                let isRed = Int((z + 100) / 1.5) % 2 == 0
                let curb = SCNNode(geometry: curbGeo)
                curb.geometry?.firstMaterial = isRed ? curbRed : curbWhite
                curb.position = SCNVector3(x, 0.06, z + 0.75)
                group.addChildNode(curb)
                z += 1.5
            }
        }

        // Guard rails
        let railMat = DriveHardCar.toonMaterial(color: UIColor(red: 0.53, green: 0.53, blue: 0.6, alpha: 1))
        for x: Float in [-5.7, 5.7] {
            let beam1Geo = SCNBox(width: 0.06, height: 0.1, length: CGFloat(segLen), chamferRadius: 0)
            beam1Geo.firstMaterial = railMat
            let beam1 = SCNNode(geometry: beam1Geo)
            beam1.position = SCNVector3(x, 0.55, 0)
            group.addChildNode(beam1)

            let beam2 = SCNNode(geometry: beam1Geo)
            beam2.position = SCNVector3(x, 0.32, 0)
            group.addChildNode(beam2)

            let postGeo = SCNBox(width: 0.08, height: 0.7, length: 0.08, chamferRadius: 0)
            postGeo.firstMaterial = railMat
            var z: Float = -segLen / 2 + 3
            while z < segLen / 2 {
                let post = SCNNode(geometry: postGeo)
                post.position = SCNVector3(x, 0.35, z)
                group.addChildNode(post)
                z += 8
            }
        }

        return group
    }

    // MARK: - Ground

    static func createGround() -> SCNNode {
        let geo = SCNPlane(width: 250, height: 350)
        geo.firstMaterial = DriveHardCar.toonMaterial(color: UIColor(red: 0.33, green: 0.8, blue: 0.33, alpha: 1))
        let node = SCNNode(geometry: geo)
        node.eulerAngles.x = -.pi / 2
        node.position.y = -0.01
        return node
    }

    // MARK: - Sidewalks

    static func createSidewalks() -> [SCNNode] {
        let swMat = DriveHardCar.toonMaterial(color: UIColor(red: 0.73, green: 0.73, blue: 0.67, alpha: 1))
        return [-6.0, 6.0].map { x -> SCNNode in
            let geo = SCNPlane(width: 1.5, height: 350)
            geo.firstMaterial = swMat
            let node = SCNNode(geometry: geo)
            node.eulerAngles.x = -.pi / 2
            node.position = SCNVector3(Float(x), 0.005, 0)
            return node
        }
    }

    // MARK: - Scenery: Trees

    static func createTree(variant: String) -> SCNNode {
        let group = SCNNode()
        let trunkMat = DriveHardCar.toonMaterial(color: UIColor(red: 0.53, green: 0.33, blue: 0.2, alpha: 1))

        if variant == "round" {
            let trunkGeo = SCNCylinder(radius: 0.18, height: 1.5)
            trunkGeo.firstMaterial = trunkMat
            let trunk = SCNNode(geometry: trunkGeo)
            trunk.position.y = 0.75
            group.addChildNode(trunk)

            let r = CGFloat.random(in: 0...0.08)
            let foliageGeo = SCNSphere(radius: 1.2)
            foliageGeo.firstMaterial = DriveHardCar.toonMaterial(color: UIColor(red: 0.2 + r, green: 0.67 + r, blue: 0.27, alpha: 1))
            let foliage = SCNNode(geometry: foliageGeo)
            foliage.position.y = 2.3
            group.addChildNode(foliage)
        } else {
            let trunkGeo = SCNCylinder(radius: 0.15, height: 1.2)
            trunkGeo.firstMaterial = trunkMat
            let trunk = SCNNode(geometry: trunkGeo)
            trunk.position.y = 0.6
            group.addChildNode(trunk)

            let r = CGFloat.random(in: 0...0.1)
            let fMat = DriveHardCar.toonMaterial(color: UIColor(red: 0.13 + r, green: 0.53 + r, blue: 0.2, alpha: 1))
            let sizes: [(radius: CGFloat, height: CGFloat, y: Float)] = [(1.0, 2.2, 2.2), (0.75, 1.7, 3.3), (0.5, 1.2, 4.2)]
            for (radius, height, y) in sizes {
                let coneGeo = SCNCone(topRadius: 0, bottomRadius: radius, height: height)
                coneGeo.firstMaterial = fMat
                let cone = SCNNode(geometry: coneGeo)
                cone.position.y = y
                group.addChildNode(cone)
            }
        }

        return group
    }

    // MARK: - Buildings

    static func createBuilding() -> SCNNode {
        let group = SCNNode()
        let h = Float.random(in: 4...12)
        let w = Float.random(in: 2.5...5.0)
        let d = Float.random(in: 2.5...4.5)
        let color = DHConst.buildingColors.randomElement()!

        let bodyGeo = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.25)
        bodyGeo.firstMaterial = DriveHardCar.toonMaterial(color: color)
        let body = SCNNode(geometry: bodyGeo)
        body.position.y = h / 2
        group.addChildNode(body)

        // Roof detail
        if Float.random(in: 0...1) > 0.4 {
            let roofGeo = SCNBox(width: CGFloat(w * 0.6), height: 0.8, length: CGFloat(d * 0.6), chamferRadius: 0.1)
            roofGeo.firstMaterial = DriveHardCar.toonMaterial(color: UIColor(red: 0.53, green: 0.53, blue: 0.6, alpha: 1))
            let roof = SCNNode(geometry: roofGeo)
            roof.position.y = h + 0.4
            group.addChildNode(roof)
        }

        // Windows (front face)
        let winOn = DriveHardCar.emissiveMaterial(color: UIColor(red: 1, green: 0.93, blue: 0.67, alpha: 1))
        let winOff = DriveHardCar.toonMaterial(color: UIColor(red: 0.2, green: 0.27, blue: 0.33, alpha: 1))
        let rows = min(5, Int(h / 1.5))
        let cols = min(3, Int(w / 0.9))
        let winGeo = SCNPlane(width: 0.45, height: 0.6)
        for r in 0..<rows {
            for c in 0..<cols {
                let lit = Float.random(in: 0...1) > 0.35
                let win = SCNNode(geometry: winGeo)
                win.geometry?.firstMaterial = lit ? winOn : winOff
                let wx = (Float(c) - Float(cols - 1) / 2) * 0.8
                let wy: Float = 1.0 + Float(r) * 1.5
                win.position = SCNVector3(wx, wy, d / 2 + 0.01)
                group.addChildNode(win)
            }
        }

        return group
    }

    // MARK: - Clouds

    static func createCloud() -> SCNNode {
        let group = SCNNode()
        let mat = DriveHardCar.toonMaterial(color: UIColor(white: 1.0, alpha: 0.9))
        let puffs = Int.random(in: 3...5)
        for i in 0..<puffs {
            let r = CGFloat.random(in: 0.5...1.3)
            let geo = SCNSphere(radius: r)
            geo.firstMaterial = mat
            let puff = SCNNode(geometry: geo)
            puff.position = SCNVector3(
                (Float(i) - Float(puffs) / 2) * 0.7,
                Float.random(in: 0...0.3),
                Float.random(in: 0...0.4)
            )
            group.addChildNode(puff)
        }
        return group
    }

    // MARK: - Lamp Posts

    static func createLampPost() -> SCNNode {
        let group = SCNNode()
        let poleMat = DriveHardCar.toonMaterial(color: UIColor(white: 0.33, alpha: 1))

        let poleGeo = SCNCylinder(radius: 0.06, height: 4)
        poleGeo.firstMaterial = poleMat
        let pole = SCNNode(geometry: poleGeo)
        pole.position.y = 2
        group.addChildNode(pole)

        let armGeo = SCNBox(width: 0.8, height: 0.04, length: 0.04, chamferRadius: 0)
        armGeo.firstMaterial = poleMat
        let arm = SCNNode(geometry: armGeo)
        arm.position = SCNVector3(0.35, 3.95, 0)
        group.addChildNode(arm)

        let lampGeo = SCNSphere(radius: 0.12)
        lampGeo.firstMaterial = DriveHardCar.emissiveMaterial(color: UIColor(red: 1, green: 0.93, blue: 0.8, alpha: 1))
        let lamp = SCNNode(geometry: lampGeo)
        lamp.position = SCNVector3(0.7, 3.85, 0)
        group.addChildNode(lamp)

        return group
    }

    // MARK: - Coin

    static func createCoin() -> SCNNode {
        let group = SCNNode()

        // Gold disc
        let discGeo = SCNCylinder(radius: 0.4, height: 0.08)
        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        goldMat.emission.contents = UIColor(red: 0.6, green: 0.4, blue: 0, alpha: 1)
        goldMat.metalness.contents = 0.8
        goldMat.roughness.contents = 0.3
        goldMat.lightingModel = .physicallyBased
        discGeo.firstMaterial = goldMat
        let disc = SCNNode(geometry: discGeo)
        disc.eulerAngles.x = .pi / 2
        group.addChildNode(disc)

        // "L" text on coin face
        let textGeo = SCNText(string: "L", extrusionDepth: 0.02)
        textGeo.font = .boldSystemFont(ofSize: 0.4)
        textGeo.firstMaterial = DriveHardCar.emissiveMaterial(color: UIColor(red: 0.4, green: 0.25, blue: 0, alpha: 1))
        let textNode = SCNNode(geometry: textGeo)
        let (minBound, maxBound) = textNode.boundingBox
        let textW = maxBound.x - minBound.x
        let textH = maxBound.y - minBound.y
        textNode.position = SCNVector3(-textW / 2, -textH / 2, 0.05)
        group.addChildNode(textNode)

        // Glow sphere
        let glowGeo = SCNSphere(radius: 0.5)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = UIColor(red: 1, green: 0.53, blue: 0, alpha: 0.25)
        glowMat.lightingModel = .constant
        glowMat.isDoubleSided = true
        glowGeo.firstMaterial = glowMat
        let glow = SCNNode(geometry: glowGeo)
        group.addChildNode(glow)

        return group
    }
}
