import Foundation
import Testing
import VoxCore
@testable import VoxAppKit

@Suite("Status bar icon renderer")
struct StatusBarIconRendererTests {
    @Test("Idle state descriptor uses open V")
    func idleDescriptor() {
        let descriptor = StatusBarIconDescriptor.make(for: .idle(processingLevel: .off))

        #expect(descriptor.monogramStyle == .openV)
        #expect(abs(descriptor.strokeWidth - CGFloat(BrandIdentity.menuIconStrokeWidth(for: .off))) < 0.000_1)
    }

    @Test("Recording state descriptor uses outlined triangle")
    func recordingDescriptor() {
        let descriptor = StatusBarIconDescriptor.make(for: .recording(processingLevel: .light))

        #expect(descriptor.monogramStyle == .outlinedTriangle)
        #expect(abs(descriptor.strokeWidth - CGFloat(BrandIdentity.menuIconStrokeWidth(for: .light))) < 0.000_1)
    }

    @Test("Processing state descriptor uses solid triangle")
    func processingDescriptor() {
        let descriptor = StatusBarIconDescriptor.make(for: .processing(processingLevel: .enhance))

        #expect(descriptor.monogramStyle == .filledTriangle)
        #expect(abs(descriptor.strokeWidth - CGFloat(BrandIdentity.menuIconStrokeWidth(for: .enhance))) < 0.000_1)
    }

    @Test("Renderer returns template icon at brand size")
    func iconMetadata() {
        let icon = StatusBarIconRenderer.makeIcon(for: .idle(processingLevel: .off))

        #expect(icon.isTemplate == true)
        #expect(abs(icon.size.width - BrandIdentity.menuIconSize) < 0.000_1)
        #expect(abs(icon.size.height - BrandIdentity.menuIconSize) < 0.000_1)
    }
}
