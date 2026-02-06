import AppKit
import VoxCore

enum StatusBarMonogramStyle: Equatable {
    case openV
    case outlinedTriangle
    case filledTriangle
}

struct StatusBarIconDescriptor: Equatable {
    let strokeWidth: CGFloat
    let monogramStyle: StatusBarMonogramStyle

    static func make(for state: StatusBarState) -> StatusBarIconDescriptor {
        let monogramStyle: StatusBarMonogramStyle

        switch state {
        case .idle:
            monogramStyle = .openV
        case .recording:
            monogramStyle = .outlinedTriangle
        case .processing:
            monogramStyle = .filledTriangle
        }

        return StatusBarIconDescriptor(
            strokeWidth: CGFloat(BrandIdentity.menuIconStrokeWidth(for: state.processingLevel)),
            monogramStyle: monogramStyle
        )
    }
}

enum StatusBarIconRenderer {
    static func makeIcon(for state: StatusBarState) -> NSImage {
        let descriptor = StatusBarIconDescriptor.make(for: state)
        let size = NSSize(width: BrandIdentity.menuIconSize, height: BrandIdentity.menuIconSize)

        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            drawMonogram(in: rect, descriptor: descriptor)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawMonogram(in rect: NSRect, descriptor: StatusBarIconDescriptor) {
        let inset: CGFloat = 2.2
        let top = rect.maxY - inset - 0.4
        let bottom = rect.minY + inset + 0.9
        let left = rect.minX + inset
        let right = rect.maxX - inset
        let center = rect.midX

        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: left, y: top))
        triangle.line(to: NSPoint(x: center, y: bottom))
        triangle.line(to: NSPoint(x: right, y: top))
        triangle.close()
        triangle.lineJoinStyle = .round
        triangle.lineCapStyle = .round

        switch descriptor.monogramStyle {
        case .openV:
            let openV = NSBezierPath()
            openV.move(to: NSPoint(x: left, y: top))
            openV.line(to: NSPoint(x: center, y: bottom))
            openV.line(to: NSPoint(x: right, y: top))
            openV.lineWidth = descriptor.strokeWidth
            openV.lineCapStyle = .round
            openV.lineJoinStyle = .round
            openV.stroke()

        case .outlinedTriangle:
            triangle.lineWidth = descriptor.strokeWidth
            triangle.stroke()

        case .filledTriangle:
            triangle.fill()
        }
    }
}
