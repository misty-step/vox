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
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 520),
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
        let style = variant.style
        menuBarPreview.style = style
        listeningPreview.style = style
        processingPreview.style = style
        copiedPreview.style = style
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

private final class MenuBarPreviewView: NSView {
    var style: HUDDesignStyle = HUDDesignVariant.aurora.style {
        didSet { applyStyle() }
    }

    private let backgroundLayer = CALayer()
    private let dotLayer = CALayer()
    private let titleField = NSTextField(labelWithString: "Vox")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(dotLayer)

        titleField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)

        NSLayoutConstraint.activate([
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28)
        ])

        applyStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 240, height: 28)
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = 8
        dotLayer.frame = CGRect(x: 12, y: bounds.midY - 5, width: 10, height: 10)
        dotLayer.cornerRadius = 5
    }

    private func applyStyle() {
        backgroundLayer.backgroundColor = style.menubarBackground.cgColor
        dotLayer.backgroundColor = style.accentColor.cgColor
        titleField.textColor = style.menubarText
    }
}

private final class HUDDesignPreview: NSView {
    enum State {
        case listening
        case processing
        case copied
    }

    static let defaultSize = NSSize(width: 170, height: 96)

    var style: HUDDesignStyle = HUDDesignVariant.aurora.style {
        didSet { applyStyle() }
    }

    var state: State {
        didSet { applyState() }
    }

    private let backgroundLayer = CAGradientLayer()
    private let dotView = NSView()
    private let spinner = NSProgressIndicator()
    private let checkLabel = NSTextField(labelWithString: "✓")
    private let messageField = NSTextField(labelWithString: "")
    private let contentStack = NSStackView()

    init(state: State) {
        self.state = state
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(backgroundLayer)

        dotView.wantsLayer = true
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dotView.heightAnchor.constraint(equalToConstant: 10).isActive = true

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        checkLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        checkLabel.textColor = .black
        checkLabel.alignment = .center
        checkLabel.translatesAutoresizingMaskIntoConstraints = false
        checkLabel.widthAnchor.constraint(equalToConstant: 14).isActive = true

        messageField.lineBreakMode = .byTruncatingTail
        messageField.maximumNumberOfLines = 1

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        contentStack.addArrangedSubview(dotView)
        contentStack.addArrangedSubview(spinner)
        contentStack.addArrangedSubview(checkLabel)
        contentStack.addArrangedSubview(messageField)

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])

        applyStyle()
        applyState()
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

    private func applyStyle() {
        backgroundLayer.colors = [style.backgroundTop.cgColor, style.backgroundBottom.cgColor]
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 1)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 0)
        backgroundLayer.borderColor = style.borderColor.cgColor
        backgroundLayer.borderWidth = style.borderWidth
        layer?.shadowColor = style.shadowColor.cgColor
        layer?.shadowOpacity = style.shadowOpacity
        layer?.shadowRadius = style.shadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        dotView.layer?.backgroundColor = style.accentColor.cgColor
        dotView.layer?.cornerRadius = 5
        checkLabel.textColor = style.accentColor

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: style.textColor,
            .kern: style.letterSpacing,
            .paragraphStyle: paragraph
        ]
        messageField.attributedStringValue = NSAttributedString(string: messageField.stringValue, attributes: attributes)
    }

    private func applyState() {
        switch state {
        case .listening:
            messageField.stringValue = "Listening"
            dotView.isHidden = false
            spinner.isHidden = true
            checkLabel.isHidden = true
        case .processing:
            messageField.stringValue = "Processing"
            dotView.isHidden = true
            spinner.isHidden = false
            checkLabel.isHidden = true
        case .copied:
            messageField.stringValue = "Copied"
            dotView.isHidden = true
            spinner.isHidden = true
            checkLabel.isHidden = false
        }
        applyStyle()
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
    case orchid

    var name: String {
        switch self {
        case .aurora: return "Aurora Glass"
        case .obsidian: return "Obsidian Pulse"
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
        case .orchid: return "Orchid Bloom"
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
                cornerRadius: 20,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 18,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.4,
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
                letterSpacing: 0.4,
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
                letterSpacing: 0.6,
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
        case .orchid:
            return HUDDesignStyle(
                name: name,
                backgroundTop: .hex(0x2B1A26),
                backgroundBottom: .hex(0x160D14),
                borderColor: .white.withAlphaComponent(0.12),
                textColor: .white.withAlphaComponent(0.9),
                accentColor: .hex(0xFF8CCF),
                cornerRadius: 18,
                borderWidth: 1,
                shadowColor: .black,
                shadowOpacity: 0.55,
                shadowRadius: 16,
                font: .systemFont(ofSize: 12, weight: .semibold),
                letterSpacing: 0.2,
                menubarBackground: .hex(0x1B1018),
                menubarText: .hex(0xF7E7F0)
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
