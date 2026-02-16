import Foundation

public struct BrandColorChannels: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum BrandIdentity {
    public static let accent = BrandColorChannels(red: 1.0, green: 0.25, blue: 0.25)

    public static let menuIconSize: Double = 18.0

    public static func menuIconStrokeWidth(for level: ProcessingLevel) -> Double {
        switch level {
        case .raw:
            return 1.6
        case .clean:
            return 2.2
        case .polish:
            return 2.8
        }
    }
}
