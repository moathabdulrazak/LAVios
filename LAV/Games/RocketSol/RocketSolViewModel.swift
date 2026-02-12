import Foundation
import SpriteKit

@Observable
final class RocketSolViewModel {
    var score: Int = 0
    var gameState: RocketSolScene.RSGameState = .waiting
    var highScore: Int = 0

    let gameScene: RocketSolScene

    init() {
        gameScene = RocketSolScene(size: CGSize(width: RSConst.gameW, height: RSConst.gameH))
        gameScene.scaleMode = .aspectFit

        gameScene.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.gameState = state
                if state == .gameOver {
                    self?.highScore = self?.gameScene.currentHighScore ?? 0
                }
            }
        }

        gameScene.onScoreChange = { [weak self] score in
            DispatchQueue.main.async {
                self?.score = score
            }
        }

        highScore = UserDefaults.standard.integer(forKey: "rocketsol_best")
    }

    func restart() {
        gameScene.restart()
    }
}
