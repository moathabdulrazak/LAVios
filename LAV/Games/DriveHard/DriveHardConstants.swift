import Foundation
import SceneKit

// MARK: - Game Constants (matching web version)

enum DHConst {
    // Lanes
    static let laneLeft: Float = -3.2
    static let laneCenter: Float = 0
    static let laneRight: Float = 3.2
    static let lanes: [Float] = [laneLeft, laneCenter, laneRight]

    // Speed
    static let baseSpeed: Float = 24
    static let maxSpeed: Float = 72
    static let speedIncrement: Float = 0.9
    static let laneSwitchDuration: Float = 0.11

    // Spawning
    static let spawnDistance: Float = -90
    static let despawnDistance: Float = 15
    static let roadSegmentLength: Float = 40
    static let numRoadSegments = 5
    static let obstaclePoolSize = 12
    static let coinPoolSize = 15

    // Collision
    static let playerHalfW: Float = 0.65
    static let playerHalfD: Float = 1.3
    static let nearMissDist: Float = 0.5

    // Difficulty thresholds
    static let diffMedium = 200
    static let diffHard = 550
    static let diffInsane = 1100
    static let diffNightmare = 2000

    // Camera
    static let cameraY: Float = 5.5
    static let cameraZ: Float = 9.0
    static let baseFOV: CGFloat = 72
    static let maxExtraFOV: CGFloat = 18

    // Fixed-point scoring (deterministic, matches web)
    static let fpScale = 1000
    static let baseSpeedFP = 24000  // baseSpeed * fpScale
    static let maxSpeedFP = 72000   // maxSpeed * fpScale
    static let fixedDT: Float = 1.0 / 120.0
    static let ticksPerSec = 120
    static let multDefaultFP = 750
    static let multHardFP = 850
    static let multInsaneFP = 1050
    static let multNightmareFP = 1350

    // Colors
    static let carColors: [String: UIColor] = [
        "taxi": UIColor(red: 0.2, green: 0.73, blue: 0.53, alpha: 1),
        "bus": UIColor(red: 0.13, green: 0.47, blue: 1.0, alpha: 1),
        "truck": UIColor(red: 0.27, green: 0.67, blue: 0.27, alpha: 1),
        "sports": UIColor(red: 1.0, green: 0.33, blue: 0.0, alpha: 1),
        "van": UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
        "ambulance": UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
    ]

    static let obstacleTypes = ["taxi", "bus", "truck", "sports", "van", "ambulance"]

    // Blue-gray palette matching web version
    static let buildingColors: [UIColor] = [
        UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1),  // #c0c8d0 light blue-gray
        UIColor(red: 0.53, green: 0.60, blue: 0.67, alpha: 1),  // #8899aa medium blue-gray
        UIColor(red: 0.69, green: 0.72, blue: 0.75, alpha: 1),  // #b0b8c0 silver blue
        UIColor(red: 0.44, green: 0.53, blue: 0.63, alpha: 1),  // #7088a0 steel blue
        UIColor(red: 0.63, green: 0.66, blue: 0.69, alpha: 1),  // #a0a8b0 cool gray
        UIColor(red: 0.56, green: 0.63, blue: 0.69, alpha: 1),  // #90a0b0 slate
        UIColor(red: 0.82, green: 0.85, blue: 0.88, alpha: 1),  // #d0d8e0 light silver
        UIColor(red: 0.38, green: 0.50, blue: 0.63, alpha: 1),  // #6080a0 deep blue-gray
    ]
}

// MARK: - Obstacle Config

struct ObstacleConfig {
    let bodyWidth: Float
    let bodyHeight: Float
    let bodyDepth: Float
    let cabinWidth: Float
    let cabinHeight: Float
    let cabinDepth: Float
    let color: UIColor
    let centerY: Float

    static func config(for type: String) -> ObstacleConfig {
        switch type {
        case "taxi":
            return ObstacleConfig(bodyWidth: 1.5, bodyHeight: 0.65, bodyDepth: 2.8, cabinWidth: 1.2, cabinHeight: 0.5, cabinDepth: 1.4, color: DHConst.carColors["taxi"]!, centerY: 0.52)
        case "bus":
            return ObstacleConfig(bodyWidth: 1.8, bodyHeight: 1.4, bodyDepth: 4.0, cabinWidth: 0, cabinHeight: 0, cabinDepth: 0, color: DHConst.carColors["bus"]!, centerY: 0.9)
        case "truck":
            return ObstacleConfig(bodyWidth: 1.5, bodyHeight: 0.9, bodyDepth: 1.4, cabinWidth: 1.5, cabinHeight: 1.0, cabinDepth: 2.0, color: DHConst.carColors["truck"]!, centerY: 0.65)
        case "sports":
            return ObstacleConfig(bodyWidth: 1.5, bodyHeight: 0.5, bodyDepth: 3.0, cabinWidth: 1.1, cabinHeight: 0.4, cabinDepth: 1.2, color: DHConst.carColors["sports"]!, centerY: 0.45)
        case "van":
            return ObstacleConfig(bodyWidth: 1.6, bodyHeight: 1.2, bodyDepth: 3.0, cabinWidth: 0, cabinHeight: 0, cabinDepth: 0, color: DHConst.carColors["van"]!, centerY: 0.8)
        case "ambulance":
            return ObstacleConfig(bodyWidth: 1.6, bodyHeight: 1.1, bodyDepth: 3.2, cabinWidth: 0, cabinHeight: 0, cabinDepth: 0, color: DHConst.carColors["ambulance"]!, centerY: 0.75)
        default:
            return ObstacleConfig(bodyWidth: 1.5, bodyHeight: 0.65, bodyDepth: 2.8, cabinWidth: 1.2, cabinHeight: 0.5, cabinDepth: 1.4, color: .gray, centerY: 0.52)
        }
    }
}
