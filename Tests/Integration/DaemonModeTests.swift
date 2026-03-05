import Foundation
import Testing

@testable import StickySpacesCLI

@Suite("Daemon mode instance lock prevents multiple daemons (CLI-C-2)")
struct DaemonModeTests {
    @Test("second flock attempt fails when lock is already held")
    func secondDaemonExitsWhenLockHeld() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("daemon-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let lockPath = tempDir.appendingPathComponent("instance.lock").path

        let fd1 = open(lockPath, O_CREAT | O_RDWR, 0o644)
        #expect(fd1 >= 0)
        let result1 = flock(fd1, LOCK_EX | LOCK_NB)
        #expect(result1 == 0, "first lock should succeed")

        let fd2 = open(lockPath, O_CREAT | O_RDWR, 0o644)
        #expect(fd2 >= 0)
        let result2 = flock(fd2, LOCK_EX | LOCK_NB)
        #expect(result2 == -1, "second lock should fail")
        #expect(errno == EWOULDBLOCK, "should fail with EWOULDBLOCK")

        close(fd2)
        close(fd1)
    }

    @Test("cleanup removes both socket and lock files")
    func cleanupRemovesSocketAndLockFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("daemon-cleanup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let socketPath = tempDir.appendingPathComponent("sock").path
        let lockPath = tempDir.appendingPathComponent("instance.lock").path
        FileManager.default.createFile(atPath: socketPath, contents: nil)
        FileManager.default.createFile(atPath: lockPath, contents: nil)

        setDaemonCleanupPaths(socket: socketPath, lock: lockPath)
        performDaemonCleanup()

        #expect(!FileManager.default.fileExists(atPath: socketPath))
        #expect(!FileManager.default.fileExists(atPath: lockPath))
    }
}
