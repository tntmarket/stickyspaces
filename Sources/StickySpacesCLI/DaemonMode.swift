import AppKit
import Darwin
import Foundation
import StickySpacesApp
import StickySpacesShared

public enum DaemonPaths {
    public static let configDir = NSHomeDirectory() + "/.config/stickyspaces"
    public static let socketPath = configDir + "/sock"
    public static let lockPath = configDir + "/instance.lock"
}

private nonisolated(unsafe) var cleanupSocketPath: String = ""
private nonisolated(unsafe) var cleanupLockPath: String = ""

private func signalHandler(_: Int32) {
    unlink(cleanupSocketPath)
    unlink(cleanupLockPath)
    _exit(0)
}

func startDaemon() async throws -> Never {
    let configDir = DaemonPaths.configDir
    let socketPath = DaemonPaths.socketPath
    let lockPath = DaemonPaths.lockPath

    try FileManager.default.createDirectory(
        atPath: configDir,
        withIntermediateDirectories: true,
        attributes: nil
    )

    let lockFD = open(lockPath, O_CREAT | O_RDWR, 0o644)
    guard lockFD >= 0 else {
        FileHandle.standardError.write(Data("error: cannot open lock file\n".utf8))
        Foundation.exit(1)
    }

    guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
        close(lockFD)
        FileHandle.standardError.write(Data("StickySpaces daemon is already running.\n".utf8))
        Foundation.exit(1)
    }

    cleanupSocketPath = socketPath
    cleanupLockPath = lockPath
    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)
    signal(SIGPIPE, SIG_IGN)

    let store = StickyStore()
    let panelSync = AppKitPanelSync()
    let yabai = FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 1))
    let manager = StickyManager(store: store, yabai: yabai, panelSync: panelSync)
    let ipcServer = IPCServer(manager: manager)
    let server = UnixSocketServer(socketPath: socketPath, ipcServer: ipcServer)

    try await server.start()
    await MainActor.run {
        NSApplication.shared.run()
    }

    fatalError("NSApplication.shared.run() returned unexpectedly")
}
