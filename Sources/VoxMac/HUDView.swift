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
        static let barCount = 31
        static let barWidth: CGFloat = 2
        static let minBarGap: CGFloat = 1
        static let barFillRatio: CGFloat = 0.93
        static let barCornerRadius: CGFloat = 2
        static let spinnerLineWidth: CGFloat = 2
        static let checkLineWidth: CGFloat = 2
        static let dotSize: CGFloat = 6
        static let dotGap: CGFloat = 6
        static let ringLineWidth: CGFloat = 1.8
        static let inlineGap: CGFloat = 10
        static let contentInsetX: CGFloat = 16
        static let stateFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        static let stateColor = NSColor.hex(0x202B36, alpha: 0.78)
        static let contentYOffset: CGFloat = 0
    }

    private let backgroundLayer = CAGradientLayer()
    private let barsLayer = CALayer()
    private var barLayers: [CALayer] = []
    private let dotsLayer = CALayer()
    private var dotLayers: [CALayer] = []
    private let ringLayer = CAShapeLayer()
    private let checkLayer = CAShapeLayer()
    private let stateField = NSTextField(labelWithString: "")
    private var averageLevel: CGFloat = 0
    private var peakLevel: CGFloat = 0
    private var smoothedAverage: CGFloat = 0
    private var smoothedPeak: CGFloat = 0
    private var barTimer: Timer?
    private var lastBarTick: CFTimeInterval = 0
    private var barPhase: CGFloat = 0
    private var barMaxHeight: CGFloat = 0
    private var messageText = ""

    var state: State = .hidden {
        didSet { applyState() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBackground()
        setupBars()
        setupDots()
        setupRing()
        setupCheckmark()
        setupStateLabel()
        applyState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showMessage(_ text: String, duration: TimeInterval) {
        messageText = messageLabel(for: text)
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

    private func setupRing() {
        ringLayer.strokeColor = Style.accentColor.cgColor
        ringLayer.fillColor = NSColor.clear.cgColor
        ringLayer.lineWidth = Style.ringLineWidth
        ringLayer.lineCap = .round
        ringLayer.isHidden = true
        layer?.addSublayer(ringLayer)
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

    private func setupStateLabel() {
        stateField.font = Style.stateFont
        stateField.textColor = Style.stateColor
        stateField.alignment = .left
        stateField.isHidden = true
        stateField.alphaValue = 0
        addSubview(stateField)
    }

    private func applyState() {
        animateVisibility()
        switch state {
        case .hidden:
            stopBarsAnimation()
            stopDotsAnimation()
            stopCheckmarkAnimation()
            stateField.isHidden = true
        case .recording:
            stopDotsAnimation()
            stopCheckmarkAnimation()
            stateField.stringValue = "Listening..."
            startBarsAnimation()
        case .processing:
            stopBarsAnimation()
            stopCheckmarkAnimation()
            stateField.stringValue = "Processing..."
            startDotsAnimation()
        case .message:
            stopBarsAnimation()
            stopDotsAnimation()
            stateField.stringValue = messageText
            startCheckmarkAnimation()
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = Style.cornerRadius
        layoutInlineContent()
        layoutBars()
        layoutDots()
        layoutCheckmark()
    }

    private func layoutInlineContent() {
        let labelSize = stateField.intrinsicContentSize
        let availableWidth = bounds.width - Style.contentInsetX * 2
        let glyphSize = glyphSizeForState()
        let gap = stateField.isHidden ? 0 : Style.inlineGap
        let totalWidth = min(availableWidth, glyphSize.width + gap + labelSize.width)
        let startX = bounds.midX - totalWidth / 2
        let centerY = bounds.midY + Style.contentYOffset

        let glyphWidth = min(glyphSize.width, availableWidth - labelSize.width - gap)
        let glyphHeight = glyphSize.height
        let glyphX = startX
        let glyphY = centerY - glyphHeight / 2
        let resolvedGlyphWidth = max(0, glyphWidth)
        let resolvedGlyphFrame = CGRect(x: glyphX, y: glyphY, width: resolvedGlyphWidth, height: glyphHeight)

        let labelX = glyphX + resolvedGlyphWidth + gap
        let labelY = centerY - labelSize.height / 2
        stateField.frame = CGRect(x: labelX, y: labelY, width: labelSize.width, height: labelSize.height)

        barsLayer.frame = resolvedGlyphFrame
        dotsLayer.frame = resolvedGlyphFrame
        ringLayer.frame = resolvedGlyphFrame
        checkLayer.frame = resolvedGlyphFrame
        stateField.textColor = Style.stateColor
    }

    private func glyphSizeForState() -> CGSize {
        switch state {
        case .recording:
            return CGSize(width: bounds.width * 0.46, height: bounds.height * 0.48)
        case .processing:
            let width = Style.dotSize * 3 + Style.dotGap * 2
            return CGSize(width: max(width, bounds.width * 0.14), height: max(Style.dotSize, bounds.height * 0.2))
        case .message:
            let size = min(bounds.height * 0.44, 28)
            return CGSize(width: size, height: size)
        case .hidden:
            return CGSize(width: bounds.width * 0.4, height: bounds.height * 0.4)
        }
    }

    private func layoutBars() {
        guard !barsLayer.frame.isEmpty else { return }
        let count = Style.barCount
        let availableWidth = barsLayer.bounds.width * Style.barFillRatio
        let gap = max(Style.minBarGap, (availableWidth - CGFloat(count) * Style.barWidth) / CGFloat(max(1, count - 1)))
        let totalWidth = CGFloat(count) * Style.barWidth + CGFloat(count - 1) * gap
        let startX = barsLayer.bounds.midX - totalWidth / 2
        barMaxHeight = barsLayer.bounds.height

        let centerY = barsLayer.bounds.midY
        for (index, bar) in barLayers.enumerated() {
            let x = startX + CGFloat(index) * (Style.barWidth + gap)
            bar.bounds = CGRect(x: 0, y: 0, width: Style.barWidth, height: barMaxHeight)
            bar.position = CGPoint(x: x + Style.barWidth / 2, y: centerY)
            bar.cornerRadius = Style.barCornerRadius
        }
        updateBars(animated: false)
    }

    private func layoutDots() {
        guard !dotsLayer.frame.isEmpty else { return }
        let totalWidth = Style.dotSize * 3 + Style.dotGap * 2
        let startX = dotsLayer.bounds.midX - totalWidth / 2
        let centerY = dotsLayer.bounds.midY
        for (index, dot) in dotLayers.enumerated() {
            let x = startX + CGFloat(index) * (Style.dotSize + Style.dotGap)
            dot.frame = CGRect(x: x, y: centerY - Style.dotSize / 2, width: Style.dotSize, height: Style.dotSize)
            dot.cornerRadius = Style.dotSize / 2
        }
    }

    private func layoutCheckmark() {
        guard !ringLayer.frame.isEmpty else { return }
        let rect = ringLayer.bounds.insetBy(dx: 2, dy: 2)
        let ringPath = CGPath(ellipseIn: rect, transform: nil)
        ringLayer.path = ringPath

        checkLayer.frame = ringLayer.frame
        let width = rect.width * 0.55
        let height = width * 0.7
        let origin = CGPoint(x: rect.midX - width / 2, y: rect.midY - height / 2)
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
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.4
            fade.toValue = 1
            fade.autoreverses = true
            fade.duration = 0.6
            fade.repeatCount = .infinity

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.9
            scale.toValue = 1.1
            scale.autoreverses = true
            scale.duration = 0.6
            scale.repeatCount = .infinity

            let group = CAAnimationGroup()
            group.animations = [fade, scale]
            group.duration = 0.6
            group.autoreverses = true
            group.repeatCount = .infinity
            group.beginTime = now + CFTimeInterval(index) * 0.15
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.add(group, forKey: "bounce")
        }
    }

    private func stopDotsAnimation() {
        dotLayers.forEach { $0.removeAnimation(forKey: "bounce") }
    }

    private func startCheckmarkAnimation() {
        ringLayer.removeAnimation(forKey: "spin")
        ringLayer.removeAnimation(forKey: "fade")
        ringLayer.opacity = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.2
        ringLayer.add(fade, forKey: "fade")

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 2.4
        spin.repeatCount = .infinity
        ringLayer.add(spin, forKey: "spin")

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
        ringLayer.removeAnimation(forKey: "fade")
        ringLayer.removeAnimation(forKey: "spin")
        checkLayer.removeAnimation(forKey: "check")
        checkLayer.strokeEnd = 0
    }

    private func updateBars(animated: Bool) {
        guard !barLayers.isEmpty else { return }
        let averageAttack: CGFloat = averageLevel > smoothedAverage ? 0.5 : 0.18
        let peakAttack: CGFloat = peakLevel > smoothedPeak ? 0.7 : 0.3
        smoothedAverage += (averageLevel - smoothedAverage) * averageAttack
        smoothedPeak += (peakLevel - smoothedPeak) * peakAttack
        let maxHeight = max(4, barMaxHeight)
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

        let mid = CGFloat(max(1, barLayers.count - 1)) / 2
        for (index, bar) in barLayers.enumerated() {
            let distance = abs(CGFloat(index) - mid) / mid
            let profile = pow(1 - min(distance, 1), 1.3)
            let wave = 0.5 + 0.5 * sin(barPhase + CGFloat(index) * 0.75)
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
        setLayer(ringLayer, visible: showCheck)
        setLayer(checkLayer, visible: showCheck)
        setView(stateField, visible: state != .hidden)
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

    private func messageLabel(for text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("clipboard") || lowercased == "copied" {
            return "Copied"
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
