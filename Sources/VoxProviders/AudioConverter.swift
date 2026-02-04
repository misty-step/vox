import Foundation

enum AudioConverter {
    static func convertCAFToWAV(from inputURL: URL, to outputURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "WAVE",
            "-d", "LEI16"
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Audio conversion failed"
            ])
        }
    }
}
