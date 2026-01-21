import Foundation

struct SessionMetadataConfig {
    let locale: String
    let sttModelId: String?
    let rewriteModelId: String
    let maxOutputTokens: Int?
    let temperature: Double?
    let thinkingLevel: String?
    let contextPath: String
}
