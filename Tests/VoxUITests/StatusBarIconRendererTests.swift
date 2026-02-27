import AppKit
import Foundation
import Testing
import VoxCore
@testable import VoxUI

@Suite("Status bar icon renderer")
struct StatusBarIconRendererTests {
    @Test("Idle state descriptor uses open V")
    func idleDescriptor() {
        let descriptor = StatusBarIconDescriptor.make(for: .idle(processingLevel: .raw))

        #expect(descriptor.monogramStyle == .openV)
        #expect(abs(descriptor.strokeWidth - CGFloat(BrandIdentity.menuIconStrokeWidth(for: .raw))) < 0.000_1)
    }

    @Test("Recording state descriptor uses outlined triangle")
    func recordingDescriptor() {
        let descriptor = StatusBarIconDescriptor.make(for: .recording(processingLevel: .clean))

        #expect(descriptor.monogramStyle == .outlinedTriangle)
        #expect(abs(descriptor.strokeWidth - CGFloat(BrandIdentity.menuIconStrokeWidth(for: .clean))) < 0.000_1)
    }

    @Test("Processing state descriptor uses solid triangle")
    func processingDescriptor() {
        let descriptor = StatusBarIconDescriptor.make(for: .processing(processingLevel: .polish))

        #expect(descriptor.monogramStyle == .filledTriangle)
        #expect(abs(descriptor.strokeWidth - CGFloat(BrandIdentity.menuIconStrokeWidth(for: .polish))) < 0.000_1)
    }

    @Test("Renderer returns template icon at brand size")
    func iconMetadata() {
        let icon = StatusBarIconRenderer.makeIcon(for: .idle(processingLevel: .raw))

        #expect(icon.isTemplate == true)
        #expect(abs(icon.size.width - BrandIdentity.menuIconSize) < 0.000_1)
        #expect(abs(icon.size.height - BrandIdentity.menuIconSize) < 0.000_1)
    }

    @Test("Geometry coordinates are pixel aligned at 1x and 2x")
    func geometryIsPixelAligned() {
        let rect = NSRect(x: 0, y: 0, width: BrandIdentity.menuIconSize, height: BrandIdentity.menuIconSize)

        for scale in [1.0, 2.0] {
            let geometry = StatusBarIconGeometry.make(in: rect, scale: scale)

            #expect(isPixelAligned(geometry.top, scale: scale))
            #expect(isPixelAligned(geometry.bottom, scale: scale))
            #expect(isPixelAligned(geometry.left, scale: scale))
            #expect(isPixelAligned(geometry.right, scale: scale))
            #expect(isPixelAligned(geometry.center, scale: scale))
        }
    }

    private func isPixelAligned(_ value: CGFloat, scale: CGFloat) -> Bool {
        abs((value * scale).rounded() - (value * scale)) < 0.000_1
    }
}
