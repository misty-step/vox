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

struct StatusBarIconGeometry: Equatable {
    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat
    let center: CGFloat

    static func make(in rect: NSRect, scale: CGFloat) -> StatusBarIconGeometry {
        let resolvedScale = max(scale, 1.0)
        let inset: CGFloat = 2.2

        return StatusBarIconGeometry(
            top: aligned(rect.maxY - inset - 0.4, scale: resolvedScale),
            bottom: aligned(rect.minY + inset + 0.9, scale: resolvedScale),
            left: aligned(rect.minX + inset, scale: resolvedScale),
            right: aligned(rect.maxX - inset, scale: resolvedScale),
            center: aligned(rect.midX, scale: resolvedScale)
        )
    }

    private static func aligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
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
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let geometry = StatusBarIconGeometry.make(in: rect, scale: scale)

        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: geometry.left, y: geometry.top))
        triangle.line(to: NSPoint(x: geometry.center, y: geometry.bottom))
        triangle.line(to: NSPoint(x: geometry.right, y: geometry.top))
        triangle.close()
        triangle.lineJoinStyle = .round
        triangle.lineCapStyle = .round

        switch descriptor.monogramStyle {
        case .openV:
            let openV = NSBezierPath()
            openV.move(to: NSPoint(x: geometry.left, y: geometry.top))
            openV.line(to: NSPoint(x: geometry.center, y: geometry.bottom))
            openV.line(to: NSPoint(x: geometry.right, y: geometry.top))
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
