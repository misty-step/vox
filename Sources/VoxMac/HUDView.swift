import AppKit
import Foundation

final class HUDView: NSView {
    enum State: Equatable {
        case hidden
        case recording
        case processing
        case message(String)
    }

    private let backgroundLayer = CALayer()
    private let dotLayer = CALayer()
    private let spinner = NSProgressIndicator()
    private let messageField = NSTextField(labelWithString: "")

    var state: State = .hidden {
        didSet { applyState() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBackground()
        setupDot()
        setupSpinner()
        setupMessage()
        applyState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showMessage(_ text: String, duration: TimeInterval) {
        messageField.stringValue = text
        state = .message(text)
    }

    private func setupBackground() {
        backgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        backgroundLayer.cornerRadius = 20
        backgroundLayer.borderWidth = 1
        backgroundLayer.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)
    }

    private func setupDot() {
        dotLayer.backgroundColor = NSColor.systemGreen.cgColor
        dotLayer.cornerRadius = 10
        layer?.addSublayer(dotLayer)
    }

    private func setupSpinner() {
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func setupMessage() {
        messageField.alignment = .center
        messageField.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        messageField.textColor = .white
        messageField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageField)

        NSLayoutConstraint.activate([
            messageField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            messageField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            messageField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func applyState() {
        switch state {
        case .hidden:
            stopPulse()
            spinner.stopAnimation(nil)
            messageField.isHidden = true
            dotLayer.isHidden = true
        case .recording:
            messageField.isHidden = true
            spinner.stopAnimation(nil)
            dotLayer.isHidden = false
            startPulse()
        case .processing:
            messageField.stringValue = "Processing…"
            messageField.isHidden = false
            stopPulse()
            dotLayer.isHidden = true
            spinner.startAnimation(nil)
        case .message:
            stopPulse()
            spinner.stopAnimation(nil)
            messageField.isHidden = false
            dotLayer.isHidden = true
        }
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        let dotSize: CGFloat = 20
        dotLayer.frame = CGRect(
            x: bounds.midX - dotSize / 2,
            y: bounds.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
    }

    private func startPulse() {
        if dotLayer.animation(forKey: "pulse") != nil {
            return
        }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.7
        animation.toValue = 1.2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.duration = 0.8
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(animation, forKey: "pulse")
    }

    private func stopPulse() {
        dotLayer.removeAnimation(forKey: "pulse")
    }
}
