import AppKit
import VoxCore

enum StatusBarBadgeStyle: Equatable {
    case ring
    case filled
    case progressArc
}

struct StatusBarIconDescriptor: Equatable {
    let strokeWidth: CGFloat
    let fillsMonogram: Bool
    let badgeStyle: StatusBarBadgeStyle

    static func make(for state: StatusBarState) -> StatusBarIconDescriptor {
        let badgeStyle: StatusBarBadgeStyle
        let fillsMonogram: Bool

        switch state {
        case .idle:
            badgeStyle = .ring
            fillsMonogram = false
        case .recording:
            badgeStyle = .filled
            fillsMonogram = true
        case .processing:
            badgeStyle = .progressArc
            fillsMonogram = false
        }

        return StatusBarIconDescriptor(
            strokeWidth: CGFloat(BrandIdentity.menuIconStrokeWidth(for: state.processingLevel)),
            fillsMonogram: fillsMonogram,
            badgeStyle: badgeStyle
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
            drawBadge(in: rect, descriptor: descriptor)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawMonogram(in rect: NSRect, descriptor: StatusBarIconDescriptor) {
        let inset: CGFloat = 2.2
        let top = rect.maxY - inset - 0.8
        let bottom = rect.minY + inset + 1.9
        let left = rect.minX + inset + 0.7
        let right = rect.maxX - inset - 4.0
        let center = (left + right) / 2.0

        let monogram = NSBezierPath()
        monogram.move(to: NSPoint(x: left, y: top))
        monogram.line(to: NSPoint(x: center, y: bottom))
        monogram.line(to: NSPoint(x: right, y: top))
        monogram.lineWidth = descriptor.strokeWidth
        monogram.lineCapStyle = .round
        monogram.lineJoinStyle = .round
        monogram.stroke()

        guard descriptor.fillsMonogram else { return }
        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: left, y: top - 0.2))
        fillPath.line(to: NSPoint(x: center, y: bottom + 0.1))
        fillPath.line(to: NSPoint(x: right, y: top - 0.2))
        fillPath.close()
        fillPath.fill()
    }

    private static func drawBadge(in rect: NSRect, descriptor: StatusBarIconDescriptor) {
        let radius: CGFloat = 2.5
        let center = NSPoint(x: rect.maxX - 4.0, y: rect.maxY - 4.0)
        let badgeRect = NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )

        switch descriptor.badgeStyle {
        case .ring:
            let ring = NSBezierPath(ovalIn: badgeRect)
            ring.lineWidth = 1.3
            ring.stroke()

        case .filled:
            let filled = NSBezierPath(ovalIn: badgeRect)
            filled.fill()

        case .progressArc:
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: 35, endAngle: 305, clockwise: false)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            arc.stroke()
        }
    }
}
