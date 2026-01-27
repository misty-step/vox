import XCTest
@testable import VoxApp

final class SingleInstanceGuardTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SingleInstanceGuard._resetForTesting()
    }

    override func tearDown() {
        SingleInstanceGuard._resetForTesting()
        super.tearDown()
    }

    func testAcquiresLockOnFirstRun() {
        let box = TestBox(lockResults: [true])

        SingleInstanceGuard._withDependenciesForTesting(box.dependencies) {
            SingleInstanceGuard.acquireOrExit()
        }

        XCTAssertEqual(box.wrotePID, box.currentPID)
        XCTAssertNil(box.exitStatus)
        XCTAssertFalse(box.events.contains("activate"))
        XCTAssertEqual(box.removedCount, 0)
    }

    func testExitsWhenLockAlreadyHeld() {
        let box = TestBox(lockResults: [false])
        box.pidInFile = 4242
        box.processExists[4242] = true

        SingleInstanceGuard._withDependenciesForTesting(box.dependencies) {
            SingleInstanceGuard.acquireOrExit()
        }

        XCTAssertEqual(box.exitStatus, 0)
        XCTAssertTrue(box.events.contains("activate"))
    }

    func testCleansUpStaleLockFromCrashedProcess() {
        let box = TestBox(lockResults: [false, true])
        box.pidInFile = 99999
        box.processExists[99999] = false

        SingleInstanceGuard._withDependenciesForTesting(box.dependencies) {
            SingleInstanceGuard.acquireOrExit()
        }

        XCTAssertEqual(box.removedCount, 1)
        XCTAssertEqual(box.wrotePID, box.currentPID)
        XCTAssertNil(box.exitStatus)
        XCTAssertFalse(box.events.contains("activate"))
    }

    func testActivatesExistingInstanceBeforeExiting() {
        let box = TestBox(lockResults: [false])
        box.pidInFile = 5151
        box.processExists[5151] = true

        SingleInstanceGuard._withDependenciesForTesting(box.dependencies) {
            SingleInstanceGuard.acquireOrExit()
        }

        let activateIndex = box.events.firstIndex(of: "activate")
        let exitIndex = box.events.firstIndex(of: "exit")
        XCTAssertNotNil(activateIndex)
        XCTAssertNotNil(exitIndex)
        if let activateIndex, let exitIndex {
            XCTAssertLessThan(activateIndex, exitIndex)
        }
    }
}

private final class TestBox {
    let lockURL = URL(fileURLWithPath: "/tmp/vox-single-instance-tests.lock")
    let currentPID: pid_t = 7777

    var lockResults: [Bool]
    var lockIndex = 0
    var nextFD: Int32 = 100

    var pidInFile: pid_t?
    var processExists: [pid_t: Bool] = [:]

    var wrotePID: pid_t?
    var exitStatus: Int32?
    var removedCount = 0
    var events: [String] = []

    init(lockResults: [Bool]) {
        self.lockResults = lockResults
    }

    var dependencies: SingleInstanceGuard.Dependencies {
        SingleInstanceGuard.Dependencies(
            lockFileURL: { self.lockURL },
            ensureDirectory: { _ in self.events.append("ensureDirectory") },
            open: { _ in
                self.events.append("open")
                self.nextFD += 1
                return self.nextFD
            },
            tryLock: { _ in
                let idx = min(self.lockIndex, self.lockResults.count - 1)
                let result = self.lockResults[idx]
                self.lockIndex += 1
                self.events.append(result ? "lock-acquired" : "lock-held")
                return result
            },
            writePID: { _, pid in
                self.wrotePID = pid
                self.events.append("write-pid")
            },
            readPID: { _ in
                self.events.append("read-pid")
                return self.pidInFile
            },
            processExists: { pid in
                self.events.append("process-exists")
                return self.processExists[pid] ?? false
            },
            removeItem: { _ in
                self.removedCount += 1
                self.events.append("remove")
            },
            activateExistingInstance: { _, _ in
                self.events.append("activate")
                return true
            },
            currentPID: { self.currentPID },
            close: { _ in self.events.append("close") },
            exit: { status in
                self.exitStatus = status
                self.events.append("exit")
            }
        )
    }
}

