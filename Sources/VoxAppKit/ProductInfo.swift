import Foundation

public struct ProductInfo: Sendable, Equatable {
    static let fallbackVersion = "0.0.0-dev"
    static let fallbackBuild = "local"
    static let defaultAttribution = "Vox by Misty Step"
    static let defaultSupportURL = URL(string: "https://github.com/misty-step/vox/issues")!

    public let version: String
    public let build: String
    public let attribution: String
    public let supportURL: URL

    public init(
        version: String,
        build: String,
        attribution: String = "Vox by Misty Step",
        supportURL: URL = URL(string: "https://github.com/misty-step/vox/issues")!
    ) {
        self.version = version
        self.build = build
        self.attribution = attribution
        self.supportURL = supportURL
    }

    public static func current() -> ProductInfo {
        resolved(infoDictionary: Bundle.main.infoDictionary)
    }

    static func resolved(infoDictionary: [String: Any]?) -> ProductInfo {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (infoDictionary?["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ProductInfo(
            version: version.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackVersion,
            build: build.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackBuild
        )
    }
}
