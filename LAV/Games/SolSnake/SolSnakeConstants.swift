import UIKit
import SpriteKit

// MARK: - Game Constants (matching web SolSnakeGameColyseus.js)

enum SNConst {
    static let arenaRadius: CGFloat = 2000
    static let arenaCenter = CGPoint(x: 2000, y: 2000)
    static let minBoostLength = 15
    static let baseSpeed: CGFloat = 270        // px/sec normal
    static let boostSpeed: CGFloat = 486       // px/sec boosting
    static let segmentSpacing: CGFloat = 5
    static let inputRate: TimeInterval = 1.0 / 30  // 30 input updates/sec
    static let pingInterval: TimeInterval = 2.0
    static let mobileZoom: CGFloat = 0.7       // 70% zoom = see 43% more

    // Rendering
    static let baseSegmentWidth: CGFloat = 10
    static let maxExtraWidth: CGFloat = 8
    static let headScale: CGFloat = 0.7        // head radius = baseWidth * 0.7
    static let orbTextureSize: CGFloat = 28    // orb diameter in points

    // Camera
    static let cameraSpringStiffness: CGFloat = 200
    static let cameraSpringDamping: CGFloat = 20

    // Orb color (all cyan)
    static let orbColor = UIColor(red: 0, green: 212.0/255, blue: 1.0, alpha: 1) // #00d4ff
}

// MARK: - Snake Skins (matching web SNAKE_SKINS array)

struct SnakeSkin {
    let name: String
    let colors: [UIColor]      // 4 gradient colors (edge -> core)
    let boostColor: UIColor    // Brightened color when boosting
}

extension SNConst {
    static let snakeSkins: [SnakeSkin] = [
        // Original 12
        SnakeSkin(name: "Neon",        colors: [.hex("00a8cc"), .hex("00c4e8"), .hex("00e0ff"), .hex("40f0ff")], boostColor: .hex("80ffff")),
        SnakeSkin(name: "Electric",    colors: [.hex("0080ff"), .hex("0099ff"), .hex("00b3ff"), .hex("40ccff")], boostColor: .hex("80d4ff")),
        SnakeSkin(name: "Ice",         colors: [.hex("40e0ff"), .hex("60e8ff"), .hex("80f0ff"), .hex("a0f8ff")], boostColor: .hex("c0ffff")),
        SnakeSkin(name: "Magenta",     colors: [.hex("cc0066"), .hex("e60073"), .hex("ff0080"), .hex("ff4099")], boostColor: .hex("ff80c0")),
        SnakeSkin(name: "Fusion",      colors: [.hex("ff0055"), .hex("ff2a6d"), .hex("ff5588"), .hex("ff80aa")], boostColor: .hex("ffa0c8")),
        SnakeSkin(name: "Volt",        colors: [.hex("00cc66"), .hex("00e673"), .hex("05ffa1"), .hex("40ffb8")], boostColor: .hex("80ffc8")),
        SnakeSkin(name: "Matrix",      colors: [.hex("00aa44"), .hex("00cc55"), .hex("00ee66"), .hex("40ff88")], boostColor: .hex("80ffaa")),
        SnakeSkin(name: "Plasma",      colors: [.hex("8800cc"), .hex("aa00e6"), .hex("cc00ff"), .hex("dd40ff")], boostColor: .hex("e080ff")),
        SnakeSkin(name: "Ultraviolet", colors: [.hex("6600aa"), .hex("8800cc"), .hex("aa00ee"), .hex("cc40ff")], boostColor: .hex("d080ff")),
        SnakeSkin(name: "Solar",       colors: [.hex("cc6600"), .hex("e68a00"), .hex("ffaa00"), .hex("ffcc40")], boostColor: .hex("ffe080")),
        SnakeSkin(name: "Fire",        colors: [.hex("cc3300"), .hex("e64a00"), .hex("ff6600"), .hex("ff8840")], boostColor: .hex("ffb080")),
        SnakeSkin(name: "Chrome",      colors: [.hex("a0b0c0"), .hex("b8c8d8"), .hex("d0e0f0"), .hex("e8f0ff")], boostColor: .hex("ffffff")),
        // Additional 12 for 24-player support
        SnakeSkin(name: "Ruby",        colors: [.hex("aa0033"), .hex("cc0044"), .hex("ee0055"), .hex("ff4077")], boostColor: .hex("ff6699")),
        SnakeSkin(name: "Emerald",     colors: [.hex("00aa66"), .hex("00cc77"), .hex("00ee88"), .hex("40ff99")], boostColor: .hex("80ffbb")),
        SnakeSkin(name: "Sapphire",    colors: [.hex("0044aa"), .hex("0055cc"), .hex("0066ee"), .hex("4088ff")], boostColor: .hex("80aaff")),
        SnakeSkin(name: "Gold",        colors: [.hex("aa8800"), .hex("ccaa00"), .hex("eecc00"), .hex("ffdd40")], boostColor: .hex("ffee80")),
        SnakeSkin(name: "Coral",       colors: [.hex("ff4040"), .hex("ff5555"), .hex("ff6a6a"), .hex("ff8888")], boostColor: .hex("ffaaaa")),
        SnakeSkin(name: "Mint",        colors: [.hex("40cc99"), .hex("55ddaa"), .hex("6aeebb"), .hex("88ffcc")], boostColor: .hex("aaffdd")),
        SnakeSkin(name: "Lavender",    colors: [.hex("9966cc"), .hex("aa77dd"), .hex("bb88ee"), .hex("cc99ff")], boostColor: .hex("ddbbff")),
        SnakeSkin(name: "Sunset",      colors: [.hex("ff6633"), .hex("ff7744"), .hex("ff8855"), .hex("ff9966")], boostColor: .hex("ffbb99")),
        SnakeSkin(name: "Ocean",       colors: [.hex("006688"), .hex("0077aa"), .hex("0088cc"), .hex("40aaee")], boostColor: .hex("80ccff")),
        SnakeSkin(name: "Rose",        colors: [.hex("cc6699"), .hex("dd77aa"), .hex("ee88bb"), .hex("ff99cc")], boostColor: .hex("ffbbdd")),
        SnakeSkin(name: "Lime",        colors: [.hex("88cc00"), .hex("99dd00"), .hex("aaee00"), .hex("bbff40")], boostColor: .hex("ddff80")),
        SnakeSkin(name: "Steel",       colors: [.hex("667788"), .hex("7788aa"), .hex("8899cc"), .hex("99aadd")], boostColor: .hex("bbccee")),
    ]
}

// MARK: - Game Colors (matching web COLORS object)

enum SNColors {
    static let bgPrimary = UIColor(red: 3/255, green: 5/255, blue: 8/255, alpha: 1)       // #030508
    static let bgSecondary = UIColor(red: 10/255, green: 15/255, blue: 24/255, alpha: 1)   // #0a0f18
    static let gridDot = UIColor(red: 0, green: 210/255, blue: 1, alpha: 0.12)             // cyan 12%
    static let arenaStroke = UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.7)          // cyan 70%
    static let arenaWarning = UIColor(red: 1, green: 42/255, blue: 109/255, alpha: 0.35)   // red 35%
    static let orbCyan = UIColor(red: 0, green: 212/255, blue: 1, alpha: 1)                // #00d4ff
    static let uiPrimary = UIColor(red: 0, green: 212/255, blue: 1, alpha: 1)              // #00d4ff
    static let uiSuccess = UIColor(red: 5/255, green: 1, blue: 161/255, alpha: 1)          // #05ffa1
    static let uiDanger = UIColor(red: 1, green: 42/255, blue: 109/255, alpha: 1)          // #ff2a6d
    static let uiWarning = UIColor(red: 1, green: 170/255, blue: 0, alpha: 1)              // #ffaa00
}

// MARK: - UIColor Hex Helper

extension UIColor {
    static func hex(_ hex: String) -> UIColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

// MARK: - Player / Orb State Models

struct PlayerState {
    let id: String
    var name: String
    var score: Int
    var kills: Int
    var isAlive: Bool
    var isBoosting: Bool
    var skin: Int
    var segments: [CGPoint]  // Head is first

    var headPosition: CGPoint { segments.first ?? SNConst.arenaCenter }
    var segmentCount: Int { segments.count }
}

struct OrbState {
    let id: String
    var position: CGPoint
    var colorIndex: Int
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let score: Int
}

struct KillNotification: Identifiable {
    let id = UUID()
    let victimName: String
    let reward: Double
    let scoreGained: Int
}

struct RefundInfo {
    let amount: Double
    let percentage: Double
    let message: String
    let signature: String?
}
