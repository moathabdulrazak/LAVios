import Foundation

enum GamePhysics {

    // MARK: - RocketSol

    static func rocketsolGenerateObstacles(seed: String) -> String {
        guard let ptr = rocketsol_generate_obstacles(seed) else { return "{}" }
        let result = String(cString: ptr)
        game_physics_free_string(ptr)
        return result
    }

    static func rocketsolVerify(seed: String, inputsJSON: String, claimedScore: Int32, obstacleDataJSON: String) -> String {
        guard let ptr = rocketsol_verify(seed, inputsJSON, claimedScore, obstacleDataJSON) else { return "{}" }
        let result = String(cString: ptr)
        game_physics_free_string(ptr)
        return result
    }

    // MARK: - DriveHard

    static func drivehardGenerateObstacles(seed: String) -> String {
        guard let ptr = drivehard_generate_obstacles(seed) else { return "{}" }
        let result = String(cString: ptr)
        game_physics_free_string(ptr)
        return result
    }

    static func drivehardVerify(seed: String, inputsJSON: String, claimedScore: Int32, obstacleDataJSON: String, breakdownJSON: String) -> String {
        guard let ptr = drivehard_verify(seed, inputsJSON, claimedScore, obstacleDataJSON, breakdownJSON) else { return "{}" }
        let result = String(cString: ptr)
        game_physics_free_string(ptr)
        return result
    }

    // MARK: - Warp

    static func warpGenerateObstacles(seed: String) -> String {
        guard let ptr = warp_generate_obstacles(seed) else { return "{}" }
        let result = String(cString: ptr)
        game_physics_free_string(ptr)
        return result
    }

    static func warpVerify(seed: String, inputsJSON: String, claimedScore: Int32, obstacleDataJSON: String, breakdownJSON: String) -> String {
        guard let ptr = warp_verify(seed, inputsJSON, claimedScore, obstacleDataJSON, breakdownJSON) else { return "{}" }
        let result = String(cString: ptr)
        game_physics_free_string(ptr)
        return result
    }
}
