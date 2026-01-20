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
        static let backgroundTop = NSColor.hex(0xF7F9FB)
        static let backgroundBottom = NSColor.hex(0xEAF0F6)
        static let borderColor = NSColor.hex(0x1F2A37, alpha: 0.14)
        static let accentColor = NSColor.hex(0x2F6DB6)
        static let cornerRadius: CGFloat = 20
        static let borderWidth: CGFloat = 1
        static let barCount = 9
        static let barWidth: CGFloat = 3
        static let barGap: CGFloat = 2
        static let barCornerRadius: CGFloat = 2
        static let spinnerLineWidth: CGFloat = 2
        static let checkLineWidth: CGFloat = 2
        static let dotSize: CGFloat = 6
        static let dotGap: CGFloat = 6
        static let captionInset: CGFloat = 10
        static let captionFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        static let captionColor = NSColor.hex(0x202B36, alpha: 0.72)
        static let contentYOffset: CGFloat = 6
    }

    private let backgroundLayer = CAGradientLayer()
    private let barsLayer = CALayer()
    private var barLayers: [CALayer] = []
    private let dotsLayer = CALayer()
    private var dotLayers: [CALayer] = []
    private let checkLayer = CAShapeLayer()
    private let captionField = NSTextField(labelWithString: "")
    private var averageLevel: CGFloat = 0
    private var peakLevel: CGFloat = 0
    private var smoothedAverage: CGFloat = 0
    private var smoothedPeak: CGFloat = 0
    private let barProfile: [CGFloat] = [0.5, 0.75, 0.95, 1.0, 0.9, 0.7, 0.55, 0.4, 0.3]
    private var barTimer: Timer?
    private var lastBarTick: CFTimeInterval = 0
    private var barPhase: CGFloat = 0

    var state: State = .hidden {
        didSet { applyState() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBackground()
        setupBars()
        setupDots()
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
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barsLayer.addSublayer(bar)
            return bar
        }
    }

    private func setupDots() {
        dotsLayer.isHidden = true
        layer?.addSublayer(dotsLayer)
        dotLayers = (0..<3).map { _ in
            let dot = CALayer()
            dot.backgroundColor = Style.accentColor.cgColor
            dot.opacity = 0.7
            dotsLayer.addSublayer(dot)
            return dot
        }
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
        animateVisibility()
        switch state {
        case .hidden:
            stopBarsAnimation()
            stopDotsAnimation()
            stopCheckmarkAnimation()
            captionField.isHidden = true
        case .recording:
            stopDotsAnimation()
            stopCheckmarkAnimation()
            captionField.isHidden = true
            startBarsAnimation()
        case .processing:
            stopBarsAnimation()
            stopCheckmarkAnimation()
            captionField.isHidden = true
            startDotsAnimation()
        case .message:
            stopBarsAnimation()
            stopDotsAnimation()
            captionField.isHidden = false
            startCheckmarkAnimation()
        }
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = Style.cornerRadius
        layoutBars()
        layoutDots()
        layoutCheckmark()
    }

    private func layoutBars() {
        barsLayer.frame = bounds
        let totalWidth = CGFloat(Style.barCount) * Style.barWidth + CGFloat(Style.barCount - 1) * Style.barGap
        let startX = bounds.midX - totalWidth / 2
        let maxHeight = min(bounds.width, bounds.height) * 0.32

        let centerY = bounds.midY + Style.contentYOffset
        for (index, bar) in barLayers.enumerated() {
            let x = startX + CGFloat(index) * (Style.barWidth + Style.barGap)
            bar.bounds = CGRect(x: 0, y: 0, width: Style.barWidth, height: maxHeight)
            bar.position = CGPoint(x: x + Style.barWidth / 2, y: centerY)
            bar.cornerRadius = Style.barCornerRadius
        }
        updateBars(animated: false)
    }

    private func layoutDots() {
        dotsLayer.frame = bounds
        let totalWidth = Style.dotSize * 3 + Style.dotGap * 2
        let startX = bounds.midX - totalWidth / 2
        let centerY = bounds.midY + Style.contentYOffset
        for (index, dot) in dotLayers.enumerated() {
            let x = startX + CGFloat(index) * (Style.dotSize + Style.dotGap)
            dot.frame = CGRect(x: x, y: centerY - Style.dotSize / 2, width: Style.dotSize, height: Style.dotSize)
            dot.cornerRadius = Style.dotSize / 2
        }
    }

    private func layoutCheckmark() {
        checkLayer.frame = bounds
        let width = min(bounds.width, bounds.height) * 0.3
        let height = width * 0.7
        let origin = CGPoint(x: bounds.midX - width / 2, y: bounds.midY + Style.contentYOffset - height / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: origin.x, y: origin.y + height * 0.55))
        path.addLine(to: CGPoint(x: origin.x + width * 0.4, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height))
        checkLayer.path = path
    }

    func updateInputLevels(average: Float, peak: Float) {
        guard case .recording = state else { return }
        averageLevel = max(0, min(1, CGFloat(average)))
        peakLevel = max(0, min(1, CGFloat(peak)))
    }

    private func startBarsAnimation() {
        if barTimer != nil {
            return
        }
        lastBarTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in
            self?.tickBars()
        }
        RunLoop.main.add(timer, forMode: .common)
        barTimer = timer
        updateBars(animated: false)
    }

    private func stopBarsAnimation() {
        barTimer?.invalidate()
        barTimer = nil
        barLayers.forEach { $0.removeAllAnimations() }
    }

    private func startDotsAnimation() {
        let now = CACurrentMediaTime()
        for (index, dot) in dotLayers.enumerated() {
            if dot.animation(forKey: "bounce") != nil {
                continue
            }
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = 0
            animation.toValue = -4
            animation.autoreverses = true
            animation.duration = 0.6
            animation.repeatCount = .infinity
            animation.beginTime = now + CFTimeInterval(index) * 0.15
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.add(animation, forKey: "bounce")
        }
    }

    private func stopDotsAnimation() {
        dotLayers.forEach { $0.removeAnimation(forKey: "bounce") }
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
        let averageAttack: CGFloat = averageLevel > smoothedAverage ? 0.5 : 0.18
        let peakAttack: CGFloat = peakLevel > smoothedPeak ? 0.7 : 0.3
        smoothedAverage += (averageLevel - smoothedAverage) * averageAttack
        smoothedPeak += (peakLevel - smoothedPeak) * peakAttack
        let maxHeight = min(bounds.width, bounds.height) * 0.36
        let minHeight = max(2, maxHeight * 0.08)
        let envelope = smoothedAverage
        let spike = smoothedPeak

        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.08)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        } else {
            CATransaction.setDisableActions(true)
        }

        for (index, bar) in barLayers.enumerated() {
            let profile = barProfile[index % barProfile.count]
            let wave = 0.5 + 0.5 * sin(barPhase + CGFloat(index) * 0.9)
            let base = envelope * profile * (0.45 + 0.55 * wave)
            let transient = spike * (0.15 + 0.15 * sin(barPhase * 1.2 + CGFloat(index) * 1.7))
            let energy = max(0.02, min(1, base + transient))
            let target = minHeight + (maxHeight - minHeight) * energy
            bar.bounds.size.height = target
        }

        CATransaction.commit()
    }

    private func tickBars() {
        let now = CACurrentMediaTime()
        let delta = now - lastBarTick
        lastBarTick = now
        barPhase += CGFloat(delta) * 8
        updateBars(animated: true)
    }

    private func animateVisibility() {
        let showBars = state == .recording
        let showDots = state == .processing
        let showCheck: Bool
        if case .message = state {
            showCheck = true
        } else {
            showCheck = false
        }

        setLayer(barsLayer, visible: showBars)
        setLayer(dotsLayer, visible: showDots)
        setLayer(checkLayer, visible: showCheck)
        setView(captionField, visible: showCheck)
    }

    private func setLayer(_ layer: CALayer, visible: Bool) {
        if visible {
            layer.isHidden = false
        }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = layer.presentation()?.opacity ?? layer.opacity
        animation.toValue = visible ? 1 : 0
        animation.duration = 0.18
        layer.opacity = visible ? 1 : 0
        layer.add(animation, forKey: "fade")
        if !visible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak layer] in
                layer?.isHidden = true
            }
        }
    }

    private func setView(_ view: NSView, visible: Bool) {
        if visible {
            view.isHidden = false
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            view.animator().alphaValue = visible ? 1 : 0
        } completionHandler: {
            if !visible {
                view.isHidden = true
            }
        }
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
