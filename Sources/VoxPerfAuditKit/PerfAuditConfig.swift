import Foundation

package enum PerfAuditError: Error, CustomStringConvertible, Equatable {
    case helpRequested
    case missingAudioPath
    case missingOutputPath
    case invalidArgument(String)
    case missingRequiredKey(String)

    package var description: String {
        switch self {
        case .helpRequested:
            return PerfAuditConfig.usage()
        case .missingAudioPath:
            return "Missing --audio <path>."
        case .missingOutputPath:
            return "Missing --output <path>."
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .missingRequiredKey(name):
            return "Missing required API key: \(name)"
        }
    }
}

package struct PerfAuditConfig {
    package let audioURL: URL
    package let outputURL: URL
    package let iterations: Int
    package let commitSHA: String?
    package let pullRequestNumber: Int?
    package let runLabel: String?
    package let environment: [String: String]

    static func usage() -> String {
        """
        Usage: swift run VoxPerfAudit --audio <path> --output <path> [options]

        Options:
          --audio <path>         Input audio file (CAF recommended).
          --output <path>        Output JSON path.
          --iterations <N>       Iterations per level (default: 3)
          --commit <sha>         Commit SHA (default: GITHUB_SHA if set)
          --pr <number>          Pull request number (optional)
          --label <string>       Run label (optional, e.g. "ci", "local")
          --help                 Show this message

        Environment:
          VOX_PERF_STT_PROVIDER  auto|elevenlabs|deepgram|whisper (default: auto)
        """
    }

    package init(arguments: [String], environment: [String: String]) throws {
        var audioPath: String?
        var outputPath: String?
        var iterations = 3
        var commitSHA: String? = environment["GITHUB_SHA"]
        var pullRequestNumber: Int?
        var runLabel: String?

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--help":
                throw PerfAuditError.helpRequested
            case "--audio":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--audio needs a value") }
                audioPath = arguments[index]
            case "--output":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--output needs a value") }
                outputPath = arguments[index]
            case "--iterations":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                    throw PerfAuditError.invalidArgument("--iterations needs an integer > 0")
                }
                iterations = value
            case "--commit":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--commit needs a value") }
                commitSHA = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
            case "--pr":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                    throw PerfAuditError.invalidArgument("--pr needs an integer > 0")
                }
                pullRequestNumber = value
            case "--label":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--label needs a value") }
                let trimmed = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
                runLabel = trimmed.isEmpty ? nil : trimmed
            default:
                throw PerfAuditError.invalidArgument("unknown option '\(arg)'")
            }
            index += 1
        }

        guard let audioPath else { throw PerfAuditError.missingAudioPath }
        guard let outputPath else { throw PerfAuditError.missingOutputPath }

        self.audioURL = Self.resolve(audioPath)
        self.outputURL = Self.resolve(outputPath)
        self.iterations = iterations
        self.commitSHA = commitSHA?.isEmpty == true ? nil : commitSHA
        self.pullRequestNumber = pullRequestNumber
        self.runLabel = runLabel
        self.environment = environment
    }

    private static func resolve(_ path: String) -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return URL(fileURLWithPath: path, relativeTo: cwd).standardizedFileURL
    }
}
