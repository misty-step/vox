import Foundation

/// Copy-ready content for sharing Vox with others.
enum ShareVox {
    static let repositoryURL = URL(string: "https://github.com/misty-step/vox")!

    /// Plain-text string placed on the clipboard when the user triggers "Share Vox…".
    static let clipboardString: String =
        "Check out Vox — a fast, privacy-first dictation app for macOS: \(repositoryURL.absoluteString)"
}
