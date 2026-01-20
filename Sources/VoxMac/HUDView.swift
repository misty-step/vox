import AppKit
import Foundation

final class HUDView: NSView {
    enum State: Equatable {
        case hidden
        case recording
        case processing
        case message(String)
    }

    private enum Style {
        static let backgroundTop = NSColor.hex(0xF1F4F7)
        static let backgroundBottom = NSColor.hex(0xDDE3EA)
        static let borderColor = NSColor.hex(0x202B36, alpha: 0.18)
        static let accentColor = NSColor.hex(0x2F6DB6)
        static let cornerRadius: CGFloat = 18
        static let borderWidth: CGFloat = 1
        static let barCount = 5
        static let barWidth: CGFloat = 4
        static let barGap: CGFloat = 4
        static let barCornerRadius: CGFloat = 2
        static let spinnerLineWidth: CGFloat = 2
        static let checkLineWidth: CGFloat = 2
        static let captionInset: CGFloat = 10
        static let captionFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        static let captionColor = NSColor.hex(0x202B36, alpha: 0.8)
    }

    private let backgroundLayer = CAGradientLayer()
    private let barsLayer = CALayer()
    private var barLayers: [CALayer] = []
    private let spinnerLayer = CAShapeLayer()
    private let checkLayer = CAShapeLayer()
    private let captionField = NSTextField(labelWithString: "")
    private var inputLevel: CGFloat = 0
    private var smoothedLevel: CGFloat = 0
    private let barProfile: [CGFloat] = [0.6, 0.9, 1.0, 0.8, 0.5]

    var state: State = .hidden {
        didSet { applyState() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBackground()
        setupBars()
        setupSpinner()
        setupCheckmark()
        setupCaption()
        applyState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showMessage(_ text: String, duration: TimeInterval) {
        captionField.stringValue = captionText(for: text)
        state = .message(text)
    }

    private func setupBackground() {
        backgroundLayer.colors = [Style.backgroundTop.cgColor, Style.backgroundBottom.cgColor]
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 1)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 0)
        backgroundLayer.borderColor = Style.borderColor.cgColor
        backgroundLayer.borderWidth = Style.borderWidth
        backgroundLayer.cornerRadius = Style.cornerRadius
        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)
    }

    private func setupBars() {
        barsLayer.isHidden = true
        layer?.addSublayer(barsLayer)
        barLayers = (0..<Style.barCount).map { _ in
            let bar = CALayer()
            bar.backgroundColor = Style.accentColor.cgColor
            bar.cornerRadius = Style.barCornerRadius
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            barsLayer.addSublayer(bar)
            return bar
        }
    }

    private func setupSpinner() {
        spinnerLayer.strokeColor = Style.accentColor.cgColor
        spinnerLayer.fillColor = NSColor.clear.cgColor
        spinnerLayer.lineWidth = Style.spinnerLineWidth
        spinnerLayer.lineCap = .round
        spinnerLayer.strokeStart = 0
        spinnerLayer.strokeEnd = 0.75
        spinnerLayer.isHidden = true
        layer?.addSublayer(spinnerLayer)
    }

    private func setupCheckmark() {
        checkLayer.strokeColor = Style.accentColor.cgColor
        checkLayer.fillColor = NSColor.clear.cgColor
        checkLayer.lineWidth = Style.checkLineWidth
        checkLayer.lineCap = .round
        checkLayer.lineJoin = .round
        checkLayer.strokeEnd = 0
        checkLayer.isHidden = true
        layer?.addSublayer(checkLayer)
    }

    private func setupCaption() {
        captionField.font = Style.captionFont
        captionField.textColor = Style.captionColor
        captionField.alignment = .center
        captionField.isHidden = true
        captionField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionField)

        NSLayoutConstraint.activate([
            captionField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Style.captionInset),
            captionField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Style.captionInset),
            captionField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Style.captionInset)
        ])
    }

    private func applyState() {
        switch state {
        case .hidden:
            stopBarsAnimation()
            stopSpinnerAnimation()
            stopCheckmarkAnimation()
            barsLayer.isHidden = true
            spinnerLayer.isHidden = true
            checkLayer.isHidden = true
            captionField.isHidden = true
        case .recording:
            stopSpinnerAnimation()
            stopCheckmarkAnimation()
            barsLayer.isHidden = false
            spinnerLayer.isHidden = true
            checkLayer.isHidden = true
            captionField.isHidden = true
            startBarsAnimation()
        case .processing:
            stopBarsAnimation()
            stopCheckmarkAnimation()
            barsLayer.isHidden = true
            spinnerLayer.isHidden = false
            checkLayer.isHidden = true
            captionField.isHidden = true
            startSpinnerAnimation()
        case .message:
            stopBarsAnimation()
            stopSpinnerAnimation()
            barsLayer.isHidden = true
            spinnerLayer.isHidden = true
            checkLayer.isHidden = false
            captionField.isHidden = false
            startCheckmarkAnimation()
        }
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = Style.cornerRadius
        layoutBars()
        layoutSpinner()
        layoutCheckmark()
    }

    private func layoutBars() {
        barsLayer.frame = bounds
        let totalWidth = CGFloat(Style.barCount) * Style.barWidth + CGFloat(Style.barCount - 1) * Style.barGap
        let startX = bounds.midX - totalWidth / 2
        let maxHeight = min(bounds.width, bounds.height) * 0.32
        let baseline = bounds.midY - maxHeight / 2

        for (index, bar) in barLayers.enumerated() {
            let x = startX + CGFloat(index) * (Style.barWidth + Style.barGap)
            bar.bounds = CGRect(x: 0, y: 0, width: Style.barWidth, height: maxHeight)
            bar.position = CGPoint(x: x + Style.barWidth / 2, y: baseline)
            bar.cornerRadius = Style.barCornerRadius
        }
        updateBars(animated: false)
    }

    private func layoutSpinner() {
        spinnerLayer.frame = bounds
        let size = min(bounds.width, bounds.height) * 0.32
        let rect = CGRect(x: bounds.midX - size / 2, y: bounds.midY - size / 2, width: size, height: size)
        spinnerLayer.path = CGPath(ellipseIn: rect, transform: nil)
    }

    private func layoutCheckmark() {
        checkLayer.frame = bounds
        let width = min(bounds.width, bounds.height) * 0.3
        let height = width * 0.7
        let origin = CGPoint(x: bounds.midX - width / 2, y: bounds.midY - height / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: origin.x, y: origin.y + height * 0.55))
        path.addLine(to: CGPoint(x: origin.x + width * 0.4, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height))
        checkLayer.path = path
    }

    func updateInputLevel(_ level: Float) {
        guard case .recording = state else { return }
        inputLevel = max(0, min(1, CGFloat(level)))
        updateBars(animated: true)
    }

    private func startBarsAnimation() {
        updateBars(animated: false)
    }

    private func stopBarsAnimation() {
        barLayers.forEach { $0.removeAnimation(forKey: "wave") }
    }

    private func startSpinnerAnimation() {
        if spinnerLayer.animation(forKey: "spin") != nil {
            return
        }
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.fromValue = 0
        animation.toValue = Double.pi * 2
        animation.duration = 1
        animation.repeatCount = .infinity
        spinnerLayer.add(animation, forKey: "spin")
    }

    private func stopSpinnerAnimation() {
        spinnerLayer.removeAnimation(forKey: "spin")
    }

    private func startCheckmarkAnimation() {
        checkLayer.removeAnimation(forKey: "check")
        checkLayer.strokeEnd = 1
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        checkLayer.add(animation, forKey: "check")
    }

    private func stopCheckmarkAnimation() {
        checkLayer.removeAnimation(forKey: "check")
        checkLayer.strokeEnd = 0
    }

    private func updateBars(animated: Bool) {
        guard !barLayers.isEmpty else { return }
        smoothedLevel = smoothedLevel * 0.7 + inputLevel * 0.3
        let maxHeight = min(bounds.width, bounds.height) * 0.32
        let minHeight = max(2, maxHeight * 0.18)
        let level = smoothedLevel

        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.08)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        } else {
            CATransaction.setDisableActions(true)
        }

        for (index, bar) in barLayers.enumerated() {
            let profile = barProfile[index % barProfile.count]
            let target = minHeight + (maxHeight - minHeight) * level * profile
            bar.bounds.size.height = target
        }

        CATransaction.commit()
    }

    private func captionText(for text: String) -> String {
        if text.lowercased().contains("clipboard") {
            return text
        }
        if text.lowercased() == "copied" {
            return "Copied to clipboard"
        }
        return text
    }
}

private extension NSColor {
    static func hex(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}
