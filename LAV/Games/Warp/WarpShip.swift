import SceneKit

enum WarpShip {

    // MARK: - Materials

    /// Toon/cel-shading fragment modifier — 4-step lighting quantization
    /// Same shader as DriveHardCar but shared via this enum for Warp
    private static let toonShaderModifier: String = """
    #pragma body
    float lum = dot(_output.color.rgb, float3(0.299, 0.587, 0.114));
    float step_val;
    if (lum > 0.75) { step_val = 1.0; }
    else if (lum > 0.50) { step_val = 0.86; }
    else if (lum > 0.25) { step_val = 0.67; }
    else { step_val = 0.39; }
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

    static func outlineMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.black
        mat.lightingModel = .constant
        mat.cullMode = .front // inverted hull outline
        return mat
    }

    // MARK: - Ship Builder

    static func createShip() -> SCNNode {
        let group = SCNNode()
        let outMat = outlineMaterial()

        // Body — cone pointing -Z (nose forward)
        let bodyGeo = SCNCone(topRadius: 0, bottomRadius: 0.22, height: 0.8)
        bodyGeo.firstMaterial = toonMaterial(color: WConst.color(0x55aaff))
        let body = SCNNode(geometry: bodyGeo)
        body.eulerAngles.x = .pi / 2
        group.addChildNode(body)

        // Body outline hull
        let boGeo = SCNCone(topRadius: 0, bottomRadius: 0.26, height: 0.86)
        boGeo.firstMaterial = outMat
        let bodyOutline = SCNNode(geometry: boGeo)
        bodyOutline.eulerAngles.x = .pi / 2
        group.addChildNode(bodyOutline)

        // Wings
        let wingGeo = SCNBox(width: 1.05, height: 0.045, length: 0.26, chamferRadius: 0)
        wingGeo.firstMaterial = toonMaterial(color: WConst.color(0x3377dd))
        group.addChildNode(SCNNode(geometry: wingGeo))

        let woGeo = SCNBox(width: 1.12, height: 0.1, length: 0.32, chamferRadius: 0)
        woGeo.firstMaterial = outMat
        group.addChildNode(SCNNode(geometry: woGeo))

        // Tail fins — two vertical
        let finGeo = SCNBox(width: 0.04, height: 0.2, length: 0.16, chamferRadius: 0)
        let finMat = toonMaterial(color: WConst.color(0x3366cc))
        let finL = SCNNode(geometry: finGeo)
        finL.position = SCNVector3(-0.22, 0.1, 0.22)
        group.addChildNode(finL)
        let finR = SCNNode(geometry: finGeo.copy() as! SCNGeometry)
        finR.geometry?.firstMaterial = finMat
        finR.position = SCNVector3(0.22, 0.1, 0.22)
        group.addChildNode(finR)
        finGeo.firstMaterial = finMat

        // Fin outlines
        let foGeo = SCNBox(width: 0.08, height: 0.26, length: 0.2, chamferRadius: 0)
        foGeo.firstMaterial = outMat
        let foL = SCNNode(geometry: foGeo)
        foL.position = SCNVector3(-0.22, 0.1, 0.22)
        group.addChildNode(foL)
        let foR = SCNNode(geometry: foGeo.copy() as! SCNGeometry)
        foR.geometry?.firstMaterial = outMat
        foR.position = SCNVector3(0.22, 0.1, 0.22)
        group.addChildNode(foR)

        // Cockpit dome
        let cockGeo = SCNSphere(radius: 0.1)
        cockGeo.firstMaterial = toonMaterial(color: WConst.color(0xaaeeff))
        let cockpit = SCNNode(geometry: cockGeo)
        cockpit.position = SCNVector3(0, 0.16, -0.08)
        group.addChildNode(cockpit)

        // Cockpit outline
        let coGeo = SCNSphere(radius: 0.13)
        coGeo.firstMaterial = outMat
        let cockOutline = SCNNode(geometry: coGeo)
        cockOutline.position = SCNVector3(0, 0.16, -0.08)
        group.addChildNode(cockOutline)

        // Engine glow
        let engGeo = SCNSphere(radius: 0.1)
        engGeo.firstMaterial = emissiveMaterial(color: WConst.color(0xff7733))
        let engine = SCNNode(geometry: engGeo)
        engine.name = "engineGlow"
        engine.position.z = 0.42
        group.addChildNode(engine)

        // Ship point light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.color = WConst.color(0xff8844)
        lightNode.light?.intensity = 250
        lightNode.light?.attenuationEndDistance = 10
        lightNode.position.z = 0.5
        group.addChildNode(lightNode)

        return group
    }
}
