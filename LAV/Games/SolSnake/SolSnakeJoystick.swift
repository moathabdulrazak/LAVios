import SwiftUI

struct SolSnakeJoystick: UIViewRepresentable {
    let onMove: (CGFloat, CGFloat) -> Void

    private let baseSize: CGFloat = 130
    private let knobSize: CGFloat = 55

    func makeUIView(context: Context) -> JoystickTouchView {
        let view = JoystickTouchView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        view.baseSize = baseSize
        view.knobSize = knobSize
        view.onMove = onMove
        return view
    }

    func updateUIView(_ uiView: JoystickTouchView, context: Context) {
        uiView.onMove = onMove
    }
}

final class JoystickTouchView: UIView {
    var baseSize: CGFloat = 130
    var knobSize: CGFloat = 55
    var onMove: ((CGFloat, CGFloat) -> Void)?

    private var joystickBase: UIView?
    private var joystickKnob: UIView?
    private var touchOrigin: CGPoint = .zero
    private var isActive = false
    private var maxDistance: CGFloat { (baseSize - knobSize) / 2 }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Only respond to touches on the left 65% of screen
        guard location.x < bounds.width * 0.65 else { return }

        isActive = true
        touchOrigin = location

        // Create joystick UI at touch point
        showJoystick(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isActive, let touch = touches.first else { return }
        let location = touch.location(in: self)

        var dx = location.x - touchOrigin.x
        var dy = location.y - touchOrigin.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > maxDistance {
            dx = (dx / distance) * maxDistance
            dy = (dy / distance) * maxDistance
        }

        // Update knob position
        joystickKnob?.center = CGPoint(
            x: baseSize / 2 + dx,
            y: baseSize / 2 + dy
        )

        // Normalize and send
        let nx = dx / maxDistance
        let ny = dy / maxDistance
        onMove?(nx, ny)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    private func endTouch() {
        guard isActive else { return }
        isActive = false
        hideJoystick()
        onMove?(0, 0)
    }

    // MARK: - Joystick UI

    private func showJoystick(at point: CGPoint) {
        joystickBase?.removeFromSuperview()

        // Base
        let base = UIView(frame: CGRect(x: 0, y: 0, width: baseSize, height: baseSize))
        base.center = point
        base.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        base.layer.cornerRadius = baseSize / 2
        base.layer.borderWidth = 2
        base.layer.borderColor = UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.4).cgColor
        base.alpha = 0
        base.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        addSubview(base)
        joystickBase = base

        // Direction ring
        let ring = UIView(frame: base.bounds.insetBy(dx: 8, dy: 8))
        ring.layer.cornerRadius = ring.bounds.width / 2
        ring.layer.borderWidth = 1
        ring.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        ring.backgroundColor = .clear
        base.addSubview(ring)

        // Knob
        let knob = UIView(frame: CGRect(x: 0, y: 0, width: knobSize, height: knobSize))
        knob.center = CGPoint(x: baseSize / 2, y: baseSize / 2)
        knob.layer.cornerRadius = knobSize / 2
        knob.layer.borderWidth = 2
        knob.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        knob.layer.shadowColor = UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.6).cgColor
        knob.layer.shadowRadius = 10
        knob.layer.shadowOpacity = 1
        knob.layer.shadowOffset = .zero

        // Gradient for knob
        let gradient = CAGradientLayer()
        gradient.frame = knob.bounds
        gradient.colors = [
            UIColor(red: 0, green: 212/255, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0, green: 170/255, blue: 220/255, alpha: 1).cgColor
        ]
        gradient.cornerRadius = knobSize / 2
        knob.layer.insertSublayer(gradient, at: 0)

        base.addSubview(knob)
        joystickKnob = knob

        // Animate in
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            base.alpha = 1
            base.transform = .identity
        }
    }

    private func hideJoystick() {
        guard let base = joystickBase else { return }

        // Reset knob to center
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            self.joystickKnob?.center = CGPoint(x: self.baseSize / 2, y: self.baseSize / 2)
        }

        // Fade out
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            base.alpha = 0
            base.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            base.removeFromSuperview()
            self.joystickBase = nil
            self.joystickKnob = nil
        }
    }
}
