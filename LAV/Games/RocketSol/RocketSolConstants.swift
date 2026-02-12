import Foundation
import SpriteKit

enum RSConst {
    // Game world (fixed resolution matching web)
    static let gameW: CGFloat = 1280
    static let gameH: CGFloat = 720

    // Boundaries (web coords: y-down, origin top-left)
    static let groundY: CGFloat = 660   // GAME_H - 60
    static let ceilY: CGFloat = 60

    // Player
    static let playerX: CGFloat = 192   // GAME_W * 0.15
    static let playerStartY: CGFloat = 360   // GAME_H / 2

    // Hitbox (relative to player position, web coords)
    static let hitOffX: CGFloat = -12
    static let hitOffY: CGFloat = -25
    static let hitW: CGFloat = 24
    static let hitH: CGFloat = 50

    // Physics (per tick at 120Hz, web coords: +y = down)
    static let gravity: CGFloat = 0.4
    static let thrust: CGFloat = -0.85
    static let vyMin: CGFloat = -10
    static let vyMax: CGFloat = 12
    static let thrustFadeDecay: CGFloat = 0.85

    // Fixed timestep
    static let fixedDT: Double = 1.0 / 120.0
    static let maxFrameTime: Double = 0.25

    // Speed ramp: speed = 10 + min(elapsed/50, 1) * 20
    static let startSpeed: CGFloat = 5    // initial spd (only for first few frames)
    static let speedBase: CGFloat = 10
    static let speedExtra: CGFloat = 20
    static let speedRampSec: CGFloat = 50

    // Obstacle spawning
    static let firstObsDist: CGFloat = 500
    static let firstRingDist: CGFloat = 300

    // Rings
    static let ringRadius: CGFloat = 35
    static let ringCollectDist: CGFloat = 55   // r + 20
    static let ringBoostAmount: CGFloat = 50

    // Scoring
    static let pipeScore: Int = 50
    static let ringScore: Int = 200

    // Trail
    static let trailMax = 15

    // Colors
    static func color(_ hex: Int) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1
        )
    }

    static let bgDark      = color(0x0a0612)
    static let neonGreen    = color(0x4ade80)
    static let neonGreenLt  = color(0x86efac)
    static let neonPurple   = color(0xc084fc)
    static let deepPurple1  = color(0x1a0a2e)
    static let deepPurple2  = color(0x2d1b4e)
    static let hotPink      = color(0x4a1942)
    static let crimson      = color(0x6b2039)
    static let midPurple    = color(0x1a1333)
    static let darkBase     = color(0x0f0a1a)
    static let pipeGray     = color(0x4b5563)
    static let pipeDkGray   = color(0x374151)
    static let capGray      = color(0x6b7280)
    static let capLtGray    = color(0x9ca3af)
    static let laserRed     = color(0xef4444)
    static let laserRedLt   = color(0xfca5a5)
    static let pipeGreen    = color(0x2d5a4a)
    static let capGreen     = color(0x3d7a5a)

    // Sky gradient stops (top to bottom in web coords)
    static let skyStops: [(UIColor, CGFloat)] = [
        (color(0x0a0612), 0),
        (color(0x1a0a2e), 0.2),
        (color(0x2d1b4e), 0.4),
        (color(0x4a1942), 0.55),
        (color(0x6b2039), 0.7),
        (color(0x1a1333), 0.85),
        (color(0x0f0a1a), 1.0),
    ]
}
