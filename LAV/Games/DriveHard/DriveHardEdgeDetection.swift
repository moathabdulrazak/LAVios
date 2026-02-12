import SceneKit
import Metal

enum DriveHardEdgeDetection {

    /// Creates an SCNTechnique for Sobel edge detection (Borderlands outline).
    /// The Metal shaders are in DriveHardShaders.metal.
    static func makeTechnique() -> SCNTechnique? {
        let dict: [String: Any] = [
            "passes": [
                "edge_pass": [
                    "draw": "DRAW_QUAD",
                    "inputs": [
                        "colorSampler": "COLOR"
                    ],
                    "metalVertexShader": "dh_edge_vertex",
                    "metalFragmentShader": "dh_edge_fragment",
                    "outputs": [
                        "color": "COLOR"
                    ]
                ] as [String: Any]
            ],
            "sequence": ["edge_pass"],
            "symbols": [:] as [String: Any]
        ]

        return SCNTechnique(dictionary: dict)
    }
}
