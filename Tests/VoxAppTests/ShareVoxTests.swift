import Testing
import Foundation
@testable import VoxAppKit

@Suite("ShareVox content")
struct ShareVoxTests {
    @Test("URL is a valid GitHub repo URL")
    func urlIsValidGitHub() {
        let url = ShareVox.repositoryURL
        #expect(url.scheme == "https")
        #expect(url.host == "github.com")
        #expect(url.path.contains("vox"))
    }

    @Test("Clipboard string contains the repository URL")
    func clipboardStringContainsURL() {
        let text = ShareVox.clipboardString
        #expect(text.contains(ShareVox.repositoryURL.absoluteString))
    }

    @Test("Clipboard string is non-empty")
    func clipboardStringNonEmpty() {
        #expect(!ShareVox.clipboardString.isEmpty)
    }
}
