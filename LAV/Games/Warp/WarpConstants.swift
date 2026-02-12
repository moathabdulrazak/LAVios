import Foundation
import UIKit

// MARK: - Warp Game Constants (matching web WarpGame.js)

enum WConst {
    // Arena
    static let arenaW: Float = 9
    static let arenaH: Float = 6

    // Player
    static let playerR: Float = 0.35
    static let hitR: Float = 0.24
    static let playerZ: Float = 0

    // Speed
    static let v0: Float = 18
    static let vMax: Float = 52
    static let touchLerp: Float = 16
    static let touchClamp: Float = 38

    // Walls
    static let nWalls = 16
    static let wallThick: Float = 0.5
    static let gapStart: Float = 4.4
    static let gapEnd: Float = 2.2
    static let spaceStart: Float = 22
    static let spaceEnd: Float = 8
    static let maxGapShift: Float = 5.5
    static let outlinePad: Float = 0.07

    // Physics
    static let fixedDT: Float = 1.0 / 120.0
    static let ticksPerSec = 120
    static let maxFrameTime: Float = 0.25

    // Fixed-point scoring (deterministic)
    static let fpScale = 1000
    static let v0Fp = 18000   // v0 * fpScale
    static let vMaxFp = 52000 // vMax * fpScale

    // Camera
    static let baseFOV: CGFloat = 68
    static let maxExtraFOV: CGFloat = 8
    static let cameraZ: Float = 6
    static let cameraY: Float = 0.5

    // Tunnel rings
    static let ringCount = 45
    static let ringSpacing: Float = 3.2

    // Wall color palettes (matching web PALETTES array)
    struct Palette {
        let base: Int
        let edge: Int
    }

    static let palettes: [Palette] = [
        Palette(base: 0x4499ff, edge: 0x88ccff),  // blue
        Palette(base: 0xff5599, edge: 0xffaacc),  // pink
        Palette(base: 0x44cc66, edge: 0x99ffbb),  // green
        Palette(base: 0xff8844, edge: 0xffcc99),  // orange
        Palette(base: 0x8855ff, edge: 0xbbaaff),  // purple
        Palette(base: 0xffcc33, edge: 0xffee99),  // yellow
        Palette(base: 0x44ccbb, edge: 0x99ffee),  // teal
        Palette(base: 0xff4455, edge: 0xffaaaa),  // red
    ]

    // Tunnel ring colors
    static let ringColors: [Int] = [0x2a1848, 0x231345, 0x351850, 0x1a1540, 0x301040]

    // MARK: - Difficulty Helpers

    /// Sigmoid difficulty curve: t^2 / (t^2 + (1-t)^2)
    static func getDifficulty(wallIdx: Int) -> Float {
        let t = Float(wallIdx) / 70.0
        let t2 = t * t
        let inv = 1 - t
        return min(1, t2 / (t2 + inv * inv + 0.001))
    }

    /// Fixed-point speed from wall index
    static func getSpeedFp(wallIdx: Int) -> Int {
        let diff = getDifficulty(wallIdx: wallIdx)
        return v0Fp + Int(diff * Float(vMaxFp - v0Fp))
    }

    /// Gap size decreases with difficulty
    static func getGapSize(difficulty: Float) -> Float {
        gapStart - difficulty * (gapStart - gapEnd)
    }

    /// Wall spacing decreases with difficulty
    static func getSpacing(difficulty: Float) -> Float {
        spaceStart - difficulty * (spaceStart - spaceEnd)
    }

    /// UIColor from hex Int
    static func color(_ hex: Int) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
