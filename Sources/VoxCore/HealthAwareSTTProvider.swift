import Foundation

public struct HealthAwareSTTProvider: STTProvider {
    public struct ProviderEntry: Sendable {
        public let name: String
        public let provider: STTProvider

        public init(name: String, provider: STTProvider) {
            self.name = name
            self.provider = provider
        }
    }

    public struct ProviderHealth: Sendable, Equatable {
        public let name: String
        public let sampleCount: Int
        public let successRate: Double
        public let averageLatency: TimeInterval
        public let transientFailures: Int
        public let permanentFailures: Int

        public init(
            name: String,
            sampleCount: Int,
            successRate: Double,
            averageLatency: TimeInterval,
            transientFailures: Int,
            permanentFailures: Int
        ) {
            self.name = name
            self.sampleCount = sampleCount
            self.successRate = successRate
            self.averageLatency = averageLatency
            self.transientFailures = transientFailures
            self.permanentFailures = permanentFailures
        }
    }

    fileprivate enum FailureClass: Sendable {
        case transient
        case permanent
    }

    private let providersByName: [String: ProviderEntry]
    private let healthStore: HealthStore
    private let onProviderSwitch: (@Sendable (_ from: String, _ to: String) -> Void)?

    public init(
        providers: [ProviderEntry],
        windowSize: Int = 20,
        onProviderSwitch: (@Sendable (_ from: String, _ to: String) -> Void)? = nil
    ) {
        precondition(!providers.isEmpty, "HealthAwareSTTProvider requires at least one provider")

        var normalizedProviders: [ProviderEntry] = []
        var seenNames = Set<String>()
        normalizedProviders.reserveCapacity(providers.count)

        for (index, entry) in providers.enumerated() {
            let normalizedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            precondition(!normalizedName.isEmpty, "Provider at index \(index) has an empty name")
            precondition(!seenNames.contains(normalizedName), "Duplicate provider name: \(normalizedName)")
            seenNames.insert(normalizedName)
            normalizedProviders.append(ProviderEntry(name: normalizedName, provider: entry.provider))
        }

        self.providersByName = Dictionary(uniqueKeysWithValues: normalizedProviders.map { ($0.name, $0) })
        self.healthStore = HealthStore(providerOrder: normalizedProviders.map(\.name), windowSize: windowSize)
        self.onProviderSwitch = onProviderSwitch
    }

    public func transcribe(audioURL: URL) async throws -> String {
        let providerNames = await healthStore.rankedProviderNames()
        var lastError: Error?

        for (index, providerName) in providerNames.enumerated() {
            guard let provider = providersByName[providerName]?.provider else {
                continue
            }

            let startedAt = CFAbsoluteTimeGetCurrent()
            do {
                let transcript = try await provider.transcribe(audioURL: audioURL)
                let latency = CFAbsoluteTimeGetCurrent() - startedAt
                await healthStore.recordSuccess(providerName: providerName, latency: latency)
                return transcript
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let latency = CFAbsoluteTimeGetCurrent() - startedAt
                await healthStore.recordFailure(
                    providerName: providerName,
                    latency: latency,
                    failureClass: classifyFailure(error)
                )
                lastError = error

                if let sttError = error as? STTError, !sttError.isFallbackEligible {
                    throw sttError
                }

                let nextIndex = index + 1
                guard nextIndex < providerNames.count else {
                    break
                }

                let nextProviderName = providerNames[nextIndex]
                print("[STT] \(providerName) failed: \(error.localizedDescription) — switching to \(nextProviderName)")
                await MainActor.run {
                    onProviderSwitch?(providerName, nextProviderName)
                }
            }
        }

        throw lastError ?? STTError.unknown("No STT providers available")
    }

    public func healthSnapshot() async -> [ProviderHealth] {
        await healthStore.snapshot()
    }

    private func classifyFailure(_ error: Error) -> FailureClass {
        guard let sttError = error as? STTError else {
            return .transient
        }
        return sttError.isTransientForHealthScoring ? .transient : .permanent
    }
}

private actor HealthStore {
    private static let latencyComparisonEpsilon: TimeInterval = 0.000_001

    private struct Sample: Sendable {
        let success: Bool
        let latency: TimeInterval
        let failureClass: HealthAwareSTTProvider.FailureClass?
    }

    private struct Metrics {
        let sampleCount: Int
        let successRate: Double
        let averageLatency: TimeInterval
        let transientFailures: Int
        let permanentFailures: Int
    }

    private let orderedProviderNames: [String]
    private let indexByProviderName: [String: Int]
    private let windowSize: Int
    private var samplesByProviderName: [String: [Sample]]

    init(providerOrder: [String], windowSize: Int) {
        self.orderedProviderNames = providerOrder
        self.indexByProviderName = Dictionary(uniqueKeysWithValues: providerOrder.enumerated().map { ($1, $0) })
        self.windowSize = max(1, windowSize)
        self.samplesByProviderName = Dictionary(uniqueKeysWithValues: providerOrder.map { ($0, []) })
    }

    func recordSuccess(providerName: String, latency: TimeInterval) {
        appendSample(
            providerName: providerName,
            sample: Sample(success: true, latency: max(0, latency), failureClass: nil)
        )
    }

    func recordFailure(
        providerName: String,
        latency: TimeInterval,
        failureClass: HealthAwareSTTProvider.FailureClass
    ) {
        appendSample(
            providerName: providerName,
            sample: Sample(success: false, latency: max(0, latency), failureClass: failureClass)
        )
    }

    func rankedProviderNames() -> [String] {
        orderedProviderNames.sorted(by: isHealthier)
    }

    func snapshot() -> [HealthAwareSTTProvider.ProviderHealth] {
        rankedProviderNames().map { providerName in
            let metrics = metrics(for: providerName)
            return HealthAwareSTTProvider.ProviderHealth(
                name: providerName,
                sampleCount: metrics.sampleCount,
                successRate: metrics.successRate,
                averageLatency: metrics.averageLatency,
                transientFailures: metrics.transientFailures,
                permanentFailures: metrics.permanentFailures
            )
        }
    }

    private func appendSample(providerName: String, sample: Sample) {
        var samples = samplesByProviderName[providerName, default: []]
        samples.append(sample)
        if samples.count > windowSize {
            samples.removeFirst()
        }
        samplesByProviderName[providerName] = samples
    }

    private func isHealthier(_ lhs: String, _ rhs: String) -> Bool {
        let left = metrics(for: lhs)
        let right = metrics(for: rhs)

        if left.permanentFailures != right.permanentFailures {
            return left.permanentFailures < right.permanentFailures
        }
        if left.successRate != right.successRate {
            return left.successRate > right.successRate
        }
        if left.transientFailures != right.transientFailures {
            return left.transientFailures < right.transientFailures
        }

        if left.sampleCount > 0, right.sampleCount > 0 {
            let latencyDelta = abs(left.averageLatency - right.averageLatency)
            if latencyDelta > Self.latencyComparisonEpsilon {
                return left.averageLatency < right.averageLatency
            }
        }

        return (indexByProviderName[lhs] ?? .max) < (indexByProviderName[rhs] ?? .max)
    }

    private func metrics(for providerName: String) -> Metrics {
        let samples = samplesByProviderName[providerName, default: []]
        guard !samples.isEmpty else {
            return Metrics(
                sampleCount: 0,
                successRate: 1.0,
                averageLatency: 0,
                transientFailures: 0,
                permanentFailures: 0
            )
        }

        var successCount = 0
        var transientFailureCount = 0
        var permanentFailureCount = 0
        var totalLatency: TimeInterval = 0

        for sample in samples {
            totalLatency += sample.latency
            if sample.success {
                successCount += 1
                continue
            }
            switch sample.failureClass {
            case .transient:
                transientFailureCount += 1
            case .permanent:
                permanentFailureCount += 1
            case nil:
                break
            }
        }

        return Metrics(
            sampleCount: samples.count,
            successRate: Double(successCount) / Double(samples.count),
            averageLatency: totalLatency / Double(samples.count),
            transientFailures: transientFailureCount,
            permanentFailures: permanentFailureCount
        )
    }
}
