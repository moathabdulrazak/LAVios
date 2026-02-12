import SwiftUI
import Observation

@Observable
final class SolSnakeViewModel {

    // MARK: - Game State

    var score: Int = 0
    var length: Int = 10
    var killCount: Int = 0
    var isBoosting = false
    var isAlive = true
    var gameStarted = false
    var showEndScreen = false
    var showDeathFlash = false
    var leaderboard: [LeaderboardEntry] = []
    var highScore: Int = 0
    var killerName: String = ""

    // Scene reference
    weak var scene: SolSnakeScene?

    // MARK: - Setup

    func setup() {
        scene?.onScoreChange = { [weak self] s in
            self?.score = s
        }
        scene?.onLengthChange = { [weak self] l in
            self?.length = l
        }
        scene?.onKill = { [weak self] name in
            guard let self else { return }
            self.killCount += 1
        }
        scene?.onDeath = { [weak self] killer in
            self?.handleDeath(killerName: killer)
        }
        scene?.onLeaderboardChange = { [weak self] lb in
            self?.leaderboard = lb
        }
    }

    // MARK: - Game Control

    func startGame() {
        score = 0
        length = 10
        killCount = 0
        isBoosting = false
        isAlive = true
        showEndScreen = false
        showDeathFlash = false
        killerName = ""
        gameStarted = true
        scene?.startGame()
    }

    func sendInput(dirX: Float, dirY: Float, isBoosting: Bool) {
        scene?.joystickDirX = CGFloat(dirX)
        scene?.joystickDirY = CGFloat(dirY)
        self.isBoosting = isBoosting && length >= SNConst.minBoostLength
        scene?.isBoosting = self.isBoosting
    }

    func restart() {
        showEndScreen = false
        startGame()
    }

    // MARK: - Death

    private func handleDeath(killerName: String) {
        isAlive = false
        self.killerName = killerName
        if score > highScore { highScore = score }
        showDeathFlash = true
        scene?.showDeathFlash()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.showDeathFlash = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showEndScreen = true
        }
    }
}
