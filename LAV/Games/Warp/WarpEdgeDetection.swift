import SceneKit
import Metal

enum WarpEdgeDetection {

    /// Creates an SCNTechnique for Sobel edge detection (Borderlands outline).
    /// The Metal shaders are in WarpShaders.metal.
    static func makeTechnique() -> SCNTechnique? {
        let dict: [String: Any] = [
            "passes": [
                "edge_pass": [
                    "draw": "DRAW_QUAD",
                    "inputs": [
                        "colorSampler": "COLOR"
                    ],
                    "metalVertexShader": "warp_edge_vertex",
                    "metalFragmentShader": "warp_edge_fragment",
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
