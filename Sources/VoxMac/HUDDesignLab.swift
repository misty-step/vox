import AppKit

public enum HUDDesignLab {
    private static var windowController: HUDDesignLabWindowController?

    public static func openIfEnabled() {
        guard ProcessInfo.processInfo.environment["VOX_DESIGN_LAB"] == "1" else { return }
        open()
    }

    public static func open() {
        if windowController == nil {
            windowController = HUDDesignLabWindowController()
        }
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class HUDDesignLabWindowController: NSWindowController {
    init() {
        let viewController = HUDDesignLabViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vox HUD Design Lab"
        window.center()
        window.contentViewController = viewController
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class HUDDesignLabViewController: NSViewController {
    private let variantPicker = NSPopUpButton()
    private let menuBarPreview = MenuBarPreviewView()
    private let listeningPreview = HUDDesignPreview(state: .listening)
    private let processingPreview = HUDDesignPreview(state: .processing)
    private let copiedPreview = HUDDesignPreview(state: .copied)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12

        let headerLabel = NSTextField(labelWithString: "Variant")
        headerLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)

        variantPicker.target = self
        variantPicker.action = #selector(handleVariantChange)
        HUDDesignVariant.allCases.forEach { variantPicker.addItem(withTitle: $0.name) }

        headerRow.addArrangedSubview(headerLabel)
        headerRow.addArrangedSubview(variantPicker)
        headerRow.addArrangedSubview(NSView())

        let stateLabels = NSStackView()
        stateLabels.orientation = .horizontal
        stateLabels.spacing = 12
        stateLabels.alignment = .centerY
        stateLabels.addArrangedSubview(label(text: "Listening"))
        stateLabels.addArrangedSubview(label(text: "Processing"))
        stateLabels.addArrangedSubview(label(text: "Copied"))

        let previewsRow = NSStackView()
        previewsRow.orientation = .horizontal
        previewsRow.alignment = .centerY
        previewsRow.spacing = 12
        previewsRow.addArrangedSubview(listeningPreview)
        previewsRow.addArrangedSubview(processingPreview)
        previewsRow.addArrangedSubview(copiedPreview)

        root.addArrangedSubview(headerRow)
        root.addArrangedSubview(menuBarPreview)
        root.addArrangedSubview(stateLabels)
        root.addArrangedSubview(previewsRow)

        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        ])

        applyVariant(HUDDesignVariant.allCases.first ?? .aurora)
    }

    @objc private func handleVariantChange() {
        let index = max(0, variantPicker.indexOfSelectedItem)
        let variant = HUDDesignVariant.allCases[index]
        applyVariant(variant)
    }

    private func applyVariant(_ variant: HUDDesignVariant) {
        let configuration = variant.configuration
        menuBarPreview.apply(style: configuration.style, icon: configuration.menuBarIcon)
        listeningPreview.apply(configuration: configuration, state: .listening)
        processingPreview.apply(configuration: configuration, state: .processing)
        copiedPreview.apply(configuration: configuration, state: .copied)
    }

    private func label(text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text.uppercased())
        field.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        field.textColor = NSColor.secondaryLabelColor
        field.alignment = .center
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: HUDDesignPreview.defaultSize.width).isActive = true
        return field
    }
}

private enum HUDMenuBarIcon {
    case dot
    case ring
    case square
    case bars
}

private final class MenuBarPreviewView: NSView {
    private let backgroundLayer = CALayer()
    private let iconLayer = CALayer()
    private let titleField = NSTextField(labelWithString: "Vox")
    private var iconBars: [CALayer] = []
    private var icon: HUDMenuBarIcon = .dot
    private var style = HUDDesignVariant.aurora.configuration.style

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(iconLayer)

        titleField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)

        NSLayoutConstraint.activate([
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30)
        ])

        apply(style: style, icon: icon)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 240, height: 28)
    }

    func apply(style: HUDDesignStyle, icon: HUDMenuBarIcon) {
        self.style = style
        self.icon = icon
        backgroundLayer.backgroundColor = style.menubarBackground.cgColor
        titleField.textColor = style.menubarText
        updateIconLayers()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = 8

        switch icon {
        case .dot, .ring, .square:
            iconLayer.frame = CGRect(x: 12, y: bounds.midY - 5, width: 10, height: 10)
        case .bars:
            iconLayer.frame = .zero
            let startX: CGFloat = 12
            let barWidths: CGFloat = 2.5
            let gap: CGFloat = 2.5
            let heights: [CGFloat] = [5, 9, 6]
            for (index, bar) in iconBars.enumerated() {
                let x = startX + CGFloat(index) * (barWidths + gap)
                let y = bounds.midY - heights[index] / 2
                bar.frame = CGRect(x: x, y: y, width: barWidths, height: heights[index])
                bar.cornerRadius = 1
            }
        }
    }

    private func updateIconLayers() {
        iconBars.forEach { $0.removeFromSuperlayer() }
        iconBars.removeAll()
        iconLayer.isHidden = false

        switch icon {
        case .dot:
            iconLayer.backgroundColor = style.accentColor.cgColor
            iconLayer.borderWidth = 0
            iconLayer.cornerRadius = 5
        case .square:
            iconLayer.backgroundColor = style.accentColor.cgColor
            iconLayer.borderWidth = 0
            iconLayer.cornerRadius = 2
        case .ring:
            iconLayer.backgroundColor = NSColor.clear.cgColor
            iconLayer.borderColor = style.accentColor.cgColor
            iconLayer.borderWidth = 2
            iconLayer.cornerRadius = 5
        case .bars:
            iconLayer.isHidden = true
            let heights: [CGFloat] = [5, 9, 6]
            for _ in heights {
                let bar = CALayer()
                bar.backgroundColor = style.accentColor.cgColor
                layer?.addSublayer(bar)
                iconBars.append(bar)
            }
        }
    }
}

private enum HUDDesignLayout {
    case inline
    case stacked
    case textOnly
    case iconOnly
}

private struct HUDDesignStateSpec {
    let text: String
    let glyph: HUDDesignGlyph
    let layout: HUDDesignLayout
}

private struct HUDDesignConfiguration {
    let style: HUDDesignStyle
    let menuBarIcon: HUDMenuBarIcon
    let listening: HUDDesignStateSpec
    let processing: HUDDesignStateSpec
    let copied: HUDDesignStateSpec

    func spec(for state: HUDDesignPreview.State) -> HUDDesignStateSpec {
        switch state {
        case .listening:
            return listening
        case .processing:
            return processing
        case .copied:
            return copied
        }
    }
}

private enum HUDDesignGlyph {
    case none
    case dot
    case pulseDot
    case bars
    case waveform
    case ring
    case dial
    case cursor
    case dots
    case spark
    case leaf
    case badge
    case spinner
    case spinnerRing
    case checkmark
}

private final class HUDDesignPreview: NSView {
    enum State {
        case listening
        case processing
        case copied
    }

    static let defaultSize = NSSize(width: 170, height: 96)

    private var style = HUDDesignVariant.aurora.configuration.style
    private var spec = HUDDesignVariant.aurora.configuration.listening

    private let backgroundLayer = CAGradientLayer()
    private let glyphView = HUDDesignGlyphView()
    private let messageField = NSTextField(labelWithString: "")
    private let contentStack = NSStackView()

    let state: State

    init(state: State) {
        self.state = state
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(backgroundLayer)

        messageField.lineBreakMode = .byTruncatingTail
        messageField.maximumNumberOfLines = 1

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        contentStack.addArrangedSubview(glyphView)
        contentStack.addArrangedSubview(messageField)

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])

        apply(configuration: HUDDesignVariant.aurora.configuration, state: state)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        Self.defaultSize
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = style.cornerRadius
    }

    func apply(configuration: HUDDesignConfiguration, state: State) {
        style = configuration.style
        spec = configuration.spec(for: state)
        updateView()
    }

    private func updateView() {
        backgroundLayer.colors = [style.backgroundTop.cgColor, style.backgroundBottom.cgColor]
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 1)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 0)
        backgroundLayer.borderColor = style.borderColor.cgColor
        backgroundLayer.borderWidth = style.borderWidth
        layer?.shadowColor = style.shadowColor.cgColor
        layer?.shadowOpacity = style.shadowOpacity
        layer?.shadowRadius = style.shadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: style.textColor,
            .kern: style.letterSpacing,
            .paragraphStyle: paragraph
        ]
        messageField.attributedStringValue = NSAttributedString(string: spec.text, attributes: attributes)

        switch spec.layout {
        case .inline:
            contentStack.orientation = .horizontal
            contentStack.spacing = 8
        case .stacked:
            contentStack.orientation = .vertical
            contentStack.spacing = 6
        case .textOnly:
            contentStack.orientation = .vertical
            contentStack.spacing = 0
        case .iconOnly:
            contentStack.orientation = .vertical
            contentStack.spacing = 0
        }

        messageField.isHidden = true
        glyphView.isHidden = spec.glyph == .none || spec.layout == .textOnly
        glyphView.configure(kind: spec.glyph, style: style)
        needsLayout = true
    }
}

private final class HUDDesignGlyphView: NSView {
    private let spinner = NSProgressIndicator()
    private let textLayer = CATextLayer()
    private var shapeLayers: [CALayer] = []
    private var kind: HUDDesignGlyph = .none
    private var style = HUDDesignVariant.aurora.configuration.style

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 24, height: 24)
    }

    func configure(kind: HUDDesignGlyph, style: HUDDesignStyle) {
        self.kind = kind
        self.style = style
        rebuildLayers()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard layer != nil else { return }

        switch kind {
        case .none, .spinner:
            break
        case .dot, .pulseDot:
            if let dot = shapeLayers.first {
                let size: CGFloat = 10
                dot.frame = CGRect(
                    x: bounds.midX - size / 2,
                    y: bounds.midY - size / 2,
                    width: size,
                    height: size
                )
                dot.cornerRadius = size / 2
            }
        case .bars, .waveform:
            let heights: [CGFloat] = kind == .bars ? [6, 12, 8, 14, 10] : [10, 6, 14, 8, 12]
            let width: CGFloat = 3
            let gap: CGFloat = 2
            let totalWidth = CGFloat(heights.count) * width + CGFloat(heights.count - 1) * gap
            let startX = bounds.midX - totalWidth / 2
            for (index, bar) in shapeLayers.enumerated() {
                let height = heights[index]
                let x = startX + CGFloat(index) * (width + gap)
                let y = bounds.midY - height / 2
                bar.frame = CGRect(x: x, y: y, width: width, height: height)
                bar.cornerRadius = 1.5
            }
        case .ring, .dial, .spinnerRing:
            let size = min(bounds.width, bounds.height) - 6
            let rect = CGRect(x: (bounds.width - size) / 2, y: (bounds.height - size) / 2, width: size, height: size)
            if let ring = shapeLayers.first as? CAShapeLayer {
                ring.frame = bounds
                ring.path = CGPath(ellipseIn: rect, transform: nil)
            }
            if kind == .dial, shapeLayers.count > 1, let arc = shapeLayers[1] as? CAShapeLayer {
                arc.frame = bounds
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let path = CGMutablePath()
                let startAngle = CGFloat(-0.8 * Double.pi)
                let endAngle = CGFloat(0.2 * Double.pi)
                path.addArc(center: center, radius: size / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                arc.path = path
            }
            if kind == .spinnerRing, let ring = shapeLayers.first as? CAShapeLayer {
                ring.strokeStart = 0
                ring.strokeEnd = 0.75
            }
        case .cursor:
            if let cursor = shapeLayers.first {
                let size = CGSize(width: 3, height: 18)
                cursor.frame = CGRect(
                    x: bounds.midX - size.width / 2,
                    y: bounds.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                cursor.cornerRadius = 1.5
            }
        case .dots:
            let size: CGFloat = 5
            let gap: CGFloat = 3
            let totalWidth = CGFloat(shapeLayers.count) * size + CGFloat(shapeLayers.count - 1) * gap
            let startX = bounds.midX - totalWidth / 2
            for (index, dot) in shapeLayers.enumerated() {
                let x = startX + CGFloat(index) * (size + gap)
                dot.frame = CGRect(x: x, y: bounds.midY - size / 2, width: size, height: size)
                dot.cornerRadius = size / 2
            }
        case .spark:
            if let spark = shapeLayers.first {
                let size: CGFloat = 12
                spark.frame = CGRect(x: bounds.midX - size / 2, y: bounds.midY - size / 2, width: size, height: size)
                spark.cornerRadius = 2
                spark.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 4))
            }
        case .leaf:
            if let leaf = shapeLayers.first {
                let size = CGSize(width: 14, height: 10)
                leaf.frame = CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
                leaf.cornerRadius = size.height / 2
                leaf.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 4))
            }
        case .badge:
            let size: CGFloat = 22
            if let badge = shapeLayers.first {
                badge.frame = CGRect(x: bounds.midX - size / 2, y: bounds.midY - size / 2, width: size, height: size)
                badge.cornerRadius = size / 2
            }
            textLayer.frame = CGRect(x: bounds.midX - size / 2, y: bounds.midY - 6, width: size, height: 12)
        case .checkmark:
            if let check = shapeLayers.first as? CAShapeLayer {
                let width: CGFloat = 16
                let height: CGFloat = 12
                let origin = CGPoint(x: bounds.midX - width / 2, y: bounds.midY - height / 2)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: origin.x, y: origin.y + height * 0.55))
                path.addLine(to: CGPoint(x: origin.x + width * 0.4, y: origin.y))
                path.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height))
                check.path = path
            }
        }

    }

    private func rebuildLayers() {
        shapeLayers.forEach { $0.removeAllAnimations() }
        shapeLayers.forEach { $0.removeFromSuperlayer() }
        shapeLayers.removeAll()
        textLayer.removeFromSuperlayer()
        spinner.removeFromSuperview()
        spinner.stopAnimation(nil)

        guard let rootLayer = layer else { return }

        switch kind {
        case .none:
            return
        case .spinner:
            addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            spinner.startAnimation(nil)
        case .spinnerRing:
            let ring = CAShapeLayer()
            ring.strokeColor = style.accentColor.cgColor
            ring.fillColor = NSColor.clear.cgColor
            ring.lineWidth = 2
            ring.lineCap = .round
            rootLayer.addSublayer(ring)
            shapeLayers = [ring]
            addSpin(to: ring, duration: 1)
        case .dot, .pulseDot:
            let dot = CALayer()
            dot.backgroundColor = style.accentColor.cgColor
            rootLayer.addSublayer(dot)
            shapeLayers = [dot]
            if kind == .pulseDot {
                addPulse(to: dot, duration: 0.9, scale: 1.2)
            } else {
                addPulse(to: dot, duration: 1.4, scale: 1.1)
            }
        case .bars, .waveform:
            let count = 5
            for _ in 0..<count {
                let bar = CALayer()
                bar.backgroundColor = style.accentColor.cgColor
                rootLayer.addSublayer(bar)
                shapeLayers.append(bar)
            }
            addStaggeredWave(to: shapeLayers, baseDelay: 0.1)
        case .ring:
            let ring = CAShapeLayer()
            ring.strokeColor = style.accentColor.cgColor
            ring.fillColor = NSColor.clear.cgColor
            ring.lineWidth = 2
            rootLayer.addSublayer(ring)
            shapeLayers = [ring]
            addSpin(to: ring, duration: 2.4)
        case .dial:
            let ring = CAShapeLayer()
            ring.strokeColor = style.textColor.withAlphaComponent(0.25).cgColor
            ring.fillColor = NSColor.clear.cgColor
            ring.lineWidth = 2
            let arc = CAShapeLayer()
            arc.strokeColor = style.accentColor.cgColor
            arc.fillColor = NSColor.clear.cgColor
            arc.lineWidth = 2
            rootLayer.addSublayer(ring)
            rootLayer.addSublayer(arc)
            shapeLayers = [ring, arc]
            addSpin(to: arc, duration: 2.2)
        case .cursor:
            let cursor = CALayer()
            cursor.backgroundColor = style.accentColor.cgColor
            rootLayer.addSublayer(cursor)
            shapeLayers = [cursor]
            addBlink(to: cursor, duration: 0.9)
        case .dots:
            for _ in 0..<3 {
                let dot = CALayer()
                dot.backgroundColor = style.accentColor.cgColor
                dot.opacity = 0.7
                rootLayer.addSublayer(dot)
                shapeLayers.append(dot)
            }
            addStaggeredBounce(to: shapeLayers, baseDelay: 0.15)
        case .spark:
            let spark = CALayer()
            spark.backgroundColor = style.accentColor.cgColor
            rootLayer.addSublayer(spark)
            shapeLayers = [spark]
            addPulse(to: spark, duration: 1.1, scale: 1.2)
        case .leaf:
            let leaf = CALayer()
            leaf.backgroundColor = style.accentColor.cgColor
            rootLayer.addSublayer(leaf)
            shapeLayers = [leaf]
            addPulse(to: leaf, duration: 1.4, scale: 1.15)
        case .badge:
            let badge = CALayer()
            badge.backgroundColor = style.accentColor.cgColor
            rootLayer.addSublayer(badge)
            shapeLayers = [badge]
            textLayer.string = "OK"
            textLayer.font = NSFont.systemFont(ofSize: 9, weight: .bold)
            textLayer.foregroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            rootLayer.addSublayer(textLayer)
            addPulse(to: badge, duration: 1.2, scale: 1.08)
        case .checkmark:
            let check = CAShapeLayer()
            check.strokeColor = style.accentColor.cgColor
            check.fillColor = NSColor.clear.cgColor
            check.lineWidth = 2
            check.lineCap = .round
            check.lineJoin = .round
            check.strokeEnd = 1
            rootLayer.addSublayer(check)
            shapeLayers = [check]
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 0.55
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            check.add(animation, forKey: "check")
        }
    }

    private func addPulse(to layer: CALayer, duration: CFTimeInterval, scale: CGFloat) {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1
        animation.toValue = scale
        animation.autoreverses = true
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "pulse")
    }

    private func addBlink(to layer: CALayer, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.2
        animation.autoreverses = true
        animation.duration = duration
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "blink")
    }

    private func addSpin(to layer: CALayer, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.fromValue = 0
        animation.toValue = Double.pi * 2
        animation.duration = duration
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "spin")
    }

    private func addStaggeredWave(to layers: [CALayer], baseDelay: CFTimeInterval) {
        let now = CACurrentMediaTime()
        for (index, layer) in layers.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 0.5
            animation.toValue = 1.3
            animation.autoreverses = true
            animation.duration = 0.8
            animation.repeatCount = .infinity
            animation.beginTime = now + CFTimeInterval(index) * baseDelay
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "wave")
        }
    }

    private func addStaggeredBounce(to layers: [CALayer], baseDelay: CFTimeInterval) {
        let now = CACurrentMediaTime()
        for (index, layer) in layers.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = 0
            animation.toValue = -4
            animation.autoreverses = true
            animation.duration = 0.6
            animation.repeatCount = .infinity
            animation.beginTime = now + CFTimeInterval(index) * baseDelay
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "bounce")
        }
    }
}

private struct HUDDesignStyle {
    let name: String
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let borderColor: NSColor
    let textColor: NSColor
    let accentColor: NSColor
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let shadowColor: NSColor
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let font: NSFont
    let letterSpacing: CGFloat
    let menubarBackground: NSColor
    let menubarText: NSColor
}

private enum HUDDesignVariant: CaseIterable {
    case aurora
    case obsidian
    case paper
    case mint
    case signal
    case cobalt
    case ember
    case ink
    case sandstone
    case vapor
    case verdant
    case slate

    var name: String {
        switch self {
        case .aurora: return "Aurora Glass"
        case .obsidian: return "Obsidian Meter"
        case .paper: return "Paper Studio"
        case .mint: return "Mint Mist"
        case .signal: return "Signal Red"
        case .cobalt: return "Cobalt Night"
        case .ember: return "Sunset Ember"
        case .ink: return "Mono Ink"
        case .sandstone: return "Sandstone"
        case .vapor: return "Vapor Orbit"
        case .verdant: return "Verdant Focus"
        case .slate: return "Slate Studio"
        }
    }

    var configuration: HUDDesignConfiguration {
        let style = self.style
        switch self {
        case .aurora:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .dot,
                listening: HUDDesignStateSpec(text: "Listening", glyph: .pulseDot, layout: .inline),
                processing: HUDDesignStateSpec(text: "Processing", glyph: .spinnerRing, layout: .inline),
                copied: HUDDesignStateSpec(text: "Copied", glyph: .checkmark, layout: .inline)
            )
        case .obsidian:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .ring,
                listening: HUDDesignStateSpec(text: "Leveling", glyph: .dial, layout: .inline),
                processing: HUDDesignStateSpec(text: "Routing", glyph: .dots, layout: .stacked),
                copied: HUDDesignStateSpec(text: "Sent", glyph: .checkmark, layout: .stacked)
            )
        case .paper:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .square,
                listening: HUDDesignStateSpec(text: "Dictating", glyph: .cursor, layout: .inline),
                processing: HUDDesignStateSpec(text: "Rewriting", glyph: .spinnerRing, layout: .iconOnly),
                copied: HUDDesignStateSpec(text: "Stamped", glyph: .checkmark, layout: .iconOnly)
            )
        case .mint:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .bars,
                listening: HUDDesignStateSpec(text: "Listening", glyph: .waveform, layout: .inline),
                processing: HUDDesignStateSpec(text: "Polishing", glyph: .bars, layout: .inline),
                copied: HUDDesignStateSpec(text: "Placed", glyph: .checkmark, layout: .inline)
            )
        case .signal:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .dot,
                listening: HUDDesignStateSpec(text: "Scanning", glyph: .ring, layout: .inline),
                processing: HUDDesignStateSpec(text: "Analyzing", glyph: .spinnerRing, layout: .inline),
                copied: HUDDesignStateSpec(text: "Locked", glyph: .checkmark, layout: .iconOnly)
            )
        case .cobalt:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .bars,
                listening: HUDDesignStateSpec(text: "Metering", glyph: .bars, layout: .inline),
                processing: HUDDesignStateSpec(text: "Orbit", glyph: .spinnerRing, layout: .stacked),
                copied: HUDDesignStateSpec(text: "Injected", glyph: .checkmark, layout: .inline)
            )
        case .ember:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .dot,
                listening: HUDDesignStateSpec(text: "Warming", glyph: .pulseDot, layout: .stacked),
                processing: HUDDesignStateSpec(text: "Blending", glyph: .spark, layout: .inline),
                copied: HUDDesignStateSpec(text: "Ready", glyph: .checkmark, layout: .iconOnly)
            )
        case .ink:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .square,
                listening: HUDDesignStateSpec(text: "LISTENING", glyph: .dot, layout: .iconOnly),
                processing: HUDDesignStateSpec(text: "WORKING", glyph: .spinnerRing, layout: .iconOnly),
                copied: HUDDesignStateSpec(text: "OK", glyph: .checkmark, layout: .iconOnly)
            )
        case .sandstone:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .dot,
                listening: HUDDesignStateSpec(text: "Listening", glyph: .dot, layout: .inline),
                processing: HUDDesignStateSpec(text: "Thinking", glyph: .dots, layout: .inline),
                copied: HUDDesignStateSpec(text: "Delivered", glyph: .checkmark, layout: .iconOnly)
            )
        case .vapor:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .ring,
                listening: HUDDesignStateSpec(text: "Signal", glyph: .waveform, layout: .inline),
                processing: HUDDesignStateSpec(text: "Synth", glyph: .dial, layout: .inline),
                copied: HUDDesignStateSpec(text: "Copied", glyph: .checkmark, layout: .iconOnly)
            )
        case .verdant:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .bars,
                listening: HUDDesignStateSpec(text: "Focus", glyph: .leaf, layout: .inline),
                processing: HUDDesignStateSpec(text: "Refine", glyph: .bars, layout: .inline),
                copied: HUDDesignStateSpec(text: "Saved", glyph: .checkmark, layout: .inline)
            )
        case .slate:
            return HUDDesignConfiguration(
                style: style,
                menuBarIcon: .square,
                listening: HUDDesignStateSpec(text: "", glyph: .bars, layout: .iconOnly),
                processing: HUDDesignStateSpec(text: "", glyph: .spinnerRing, layout: .iconOnly),
                copied: HUDDesignStateSpec(text: "", glyph: .checkmark, layout: .iconOnly)
            )
        }
    }

    var style: HUDDesignStyle {
        switch self {
        case .aurora:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x1E2533),
                backgroundBottom: .hex(0x10141C),
                borderColor: .white.withAlphaComponent(0.14),
                textColor: .white.withAlphaComponent(0.9),
                accentColor: .hex(0x6EF0D9),
                cornerRadius: 18,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.45,
                shadowRadius: 16,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.2,
                menubarBackground: .hex(0x0F131B),
                menubarText: .hex(0xE6EDF7)
            )
        case .obsidian:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x1A1A1D),
                backgroundBottom: .hex(0x0B0B0D),
                borderColor: .white.withAlphaComponent(0.08),
                textColor: .white.withAlphaComponent(0.86),
                accentColor: .hex(0xF0B86E),
                cornerRadius: 22,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 18,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.6,
                menubarBackground: .hex(0x111115),
                menubarText: .hex(0xF1E4D2)
            )
        case .paper:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0xF6F1EA),
                backgroundBottom: .hex(0xEFE7DB),
                borderColor: .hex(0x453B30, alpha: 0.18),
                textColor: .hex(0x3C352F),
                accentColor: .hex(0xA97453),
                cornerRadius: 16,
                borderWidth: 1,
                shadowColor: .hex(0x453B30),
                shadowOpacity: 0.18,
                shadowRadius: 12,
                font: .systemFont(ofSize: 12, weight: .medium),
                letterSpacing: 0.3,
                menubarBackground: .hex(0xF1E7D6),
                menubarText: .hex(0x3C352F)
            )
        case .mint:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0xECF9F5),
                backgroundBottom: .hex(0xDCEFE7),
                borderColor: .hex(0x000000, alpha: 0.1),
                textColor: .hex(0x1A3D33),
                accentColor: .hex(0x2FA77D),
                cornerRadius: 18,
                borderWidth: 1,
                shadowColor: .hex(0x143C30),
                shadowOpacity: 0.15,
                shadowRadius: 14,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.2,
                menubarBackground: .hex(0xD6EFE6),
                menubarText: .hex(0x1A3D33)
            )
        case .signal:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x251516),
                backgroundBottom: .hex(0x140B0B),
                borderColor: .white.withAlphaComponent(0.12),
                textColor: .white.withAlphaComponent(0.92),
                accentColor: .hex(0xFF5D5D),
                cornerRadius: 14,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.5,
                shadowRadius: 14,
                font: .systemFont(ofSize: 12, weight: .bold),
                letterSpacing: 0.5,
                menubarBackground: .hex(0x1A0E0E),
                menubarText: .hex(0xFFEAEB)
            )
        case .cobalt:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x101A2F),
                backgroundBottom: .hex(0x0A0F1F),
                borderColor: .white.withAlphaComponent(0.1),
                textColor: .white.withAlphaComponent(0.9),
                accentColor: .hex(0x7AA7FF),
                cornerRadius: 22,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 18,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.1,
                menubarBackground: .hex(0x0B1121),
                menubarText: .hex(0xDBE7FF)
            )
        case .ember:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x2A1A12),
                backgroundBottom: .hex(0x17100B),
                borderColor: .white.withAlphaComponent(0.12),
                textColor: .white.withAlphaComponent(0.9),
                accentColor: .hex(0xFF9B5F),
                cornerRadius: 18,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 16,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.2,
                menubarBackground: .hex(0x1C120C),
                menubarText: .hex(0xF6E1D2)
            )
        case .ink:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0xF0F0F0),
                backgroundBottom: .hex(0xE1E1E1),
                borderColor: .hex(0x1C1C1C, alpha: 0.2),
                textColor: .hex(0x1C1C1C),
                accentColor: .hex(0x1C1C1C),
                cornerRadius: 12,
                borderWidth: 1,
                shadowColor: .hex(0x121212),
                shadowOpacity: 0.15,
                shadowRadius: 10,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 1,
                menubarBackground: .hex(0xE2E2E2),
                menubarText: .hex(0x1C1C1C)
            )
        case .sandstone:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0xF7EFE3),
                backgroundBottom: .hex(0xE8DCCB),
                borderColor: .hex(0x5C4A38, alpha: 0.2),
                textColor: .hex(0x4B3A2C),
                accentColor: .hex(0xB88A5B),
                cornerRadius: 20,
                borderWidth: 1,
                shadowColor: .hex(0x5C4A38),
                shadowOpacity: 0.2,
                shadowRadius: 12,
                font: .systemFont(ofSize: 12, weight: .medium),
                letterSpacing: 0.3,
                menubarBackground: .hex(0xEDE0CD),
                menubarText: .hex(0x4B3A2C)
            )
        case .vapor:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x281B3D),
                backgroundBottom: .hex(0x140C24),
                borderColor: .white.withAlphaComponent(0.16),
                textColor: .white.withAlphaComponent(0.9),
                accentColor: .hex(0xB085FF),
                cornerRadius: 16,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 16,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.3,
                menubarBackground: .hex(0x1B112B),
                menubarText: .hex(0xEFE6FF)
            )
        case .verdant:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x172318),
                backgroundBottom: .hex(0x0B140C),
                borderColor: .white.withAlphaComponent(0.1),
                textColor: .white.withAlphaComponent(0.9),
                accentColor: .hex(0x5CD48F),
                cornerRadius: 24,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 16,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.2,
                menubarBackground: .hex(0x0F1B10),
                menubarText: .hex(0xDBF7E7)
            )
        case .slate:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0xF1F4F7),
                backgroundBottom: .hex(0xDDE3EA),
                borderColor: .hex(0x202B36, alpha: 0.18),
                textColor: .hex(0x202B36),
                accentColor: .hex(0x2F6DB6),
                cornerRadius: 18,
                borderWidth: 1,
                shadowColor: .hex(0x202B36),
                shadowOpacity: 0.2,
                shadowRadius: 12,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.2,
                menubarBackground: .hex(0xD9E2ED),
                menubarText: .hex(0x202B36)
            )
        }
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
