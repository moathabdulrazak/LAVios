import SwiftUI
import Observation

@Observable
final class DriveHardViewModel {
    var score: Int = 0
    var coins: Int = 0
    var speedPercent: Float = 0
    var gameState: DriveHardScene.GameState = .waiting
    var highScore: Int = 0
    var showNearMiss = false
    var showCoinCollect = false

    let gameScene = DriveHardScene()

    var inputRecordingJSON: String {
        guard let data = try? JSONSerialization.data(withJSONObject: gameScene.inputRecording),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

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
        gameScene.onCoinsChange = { [weak self] c in
            DispatchQueue.main.async { self?.coins = c }
        }
        gameScene.onSpeedChange = { [weak self] pct in
            DispatchQueue.main.async { self?.speedPercent = pct }
        }
        gameScene.onNearMiss = { [weak self] in
            DispatchQueue.main.async {
                self?.showNearMiss = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self?.showNearMiss = false
                }
            }
        }
        gameScene.onCoinCollect = { [weak self] in
            DispatchQueue.main.async {
                self?.showCoinCollect = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.showCoinCollect = false
                }
            }
        }
    }

    func swipeLeft() {
        gameScene.handleSwipe(direction: -1)
    }

    func swipeRight() {
        gameScene.handleSwipe(direction: 1)
    }

    func tapToStart() {
        if gameState == .waiting || gameState == .gameOver {
            gameScene.startGame()
        }
    }

    func restart() {
        gameScene.startGame()
    }
}
