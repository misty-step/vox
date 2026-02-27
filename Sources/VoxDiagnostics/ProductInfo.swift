import Foundation

public struct ProductInfo: Sendable, Equatable {
    static let fallbackVersion = "0.0.0-dev"
    static let fallbackBuild = "local"
    static let envVersionKey = "VOX_APP_VERSION"
    static let envBuildKey = "VOX_BUILD_NUMBER"
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
        resolved(
            infoDictionary: Bundle.main.infoDictionary,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static func resolved(infoDictionary: [String: Any]?) -> ProductInfo {
        resolved(infoDictionary: infoDictionary, environment: [:])
    }

    static func resolved(infoDictionary: [String: Any]?, environment: [String: String]) -> ProductInfo {
        let version = normalized(infoDictionary?["CFBundleShortVersionString"] as? String)
        let build = normalized(infoDictionary?["CFBundleVersion"] as? String)
        let envVersion = normalized(environment[envVersionKey])
        let envBuild = normalized(environment[envBuildKey])

        return ProductInfo(
            version: version ?? envVersion ?? fallbackVersion,
            build: build ?? envBuild ?? fallbackBuild
        )
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
