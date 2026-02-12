import SwiftUI
import Observation

@Observable
final class WarpViewModel {
    var score: Int = 0
    var combo: Int = 0
    var speedPercent: Float = 0
    var gameState: WarpScene.GameState = .waiting
    var highScore: Int = 0
    var wallsPassed: Int = 0
    var showWallPass = false

    let gameScene = WarpScene()

    func setup() {
        gameScene.setupScene()
        highScore = gameScene.highScore

        gameScene.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.gameState = state
                if state == .gameOver {
                    self?.highScore = self?.gameScene.highScore ?? 0
                }
            }
        }
        gameScene.onScoreChange = { [weak self] s in
            DispatchQueue.main.async { self?.score = s }
        }
        gameScene.onComboChange = { [weak self] c in
            DispatchQueue.main.async {
                self?.combo = c
                self?.wallsPassed = self?.gameScene.wallsPassed ?? 0
            }
        }
        gameScene.onSpeedChange = { [weak self] pct in
            DispatchQueue.main.async { self?.speedPercent = pct }
        }
        gameScene.onWallPass = { [weak self] in
            DispatchQueue.main.async {
                self?.showWallPass = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.showWallPass = false
                }
            }
        }
    }

    func tapToStart() {
        if gameState == .waiting || gameState == .gameOver {
            gameScene.startGame()
        }
    }

    func restart() {
        gameScene.startGame()
    }

    // Touch forwarding
    func touchBegan(normalizedX: Float, normalizedY: Float) {
        gameScene.handleTouchBegan(normalizedX: normalizedX, normalizedY: normalizedY)
    }

    func touchMoved(normalizedX: Float, normalizedY: Float) {
        gameScene.handleTouchMoved(normalizedX: normalizedX, normalizedY: normalizedY)
    }

    func touchEnded() {
        gameScene.handleTouchEnded()
    }
}
