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

nonisolated(unsafe) var cleanupSocketCStr: UnsafeMutablePointer<CChar>?
nonisolated(unsafe) var cleanupLockCStr: UnsafeMutablePointer<CChar>?

func performDaemonCleanup() {
    if let cStr = cleanupSocketCStr { unlink(cStr) }
    if let cStr = cleanupLockCStr { unlink(cStr) }
}

func setDaemonCleanupPaths(socket: String, lock: String) {
    cleanupSocketCStr?.deallocate()
    cleanupLockCStr?.deallocate()
    cleanupSocketCStr = strdup(socket)
    cleanupLockCStr = strdup(lock)
}

private func signalHandler(_: Int32) {
    performDaemonCleanup()
    _exit(0)
}

@MainActor
private class DaemonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateCancel
    }
}

@MainActor private let daemonDelegate = DaemonAppDelegate()

func startDaemon() async throws -> Never {
    let configDir = DaemonPaths.configDir
    let socketPath = DaemonPaths.socketPath
    let lockPath = DaemonPaths.lockPath

    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)
    signal(SIGHUP, signalHandler)
    signal(SIGPIPE, SIG_IGN)

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

    setDaemonCleanupPaths(socket: socketPath, lock: lockPath)

    let store = StickyStore()
    let panelSync = AppKitPanelSync()
    let yabai = FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 1))
    let manager = StickyManager(store: store, yabai: yabai, panelSync: panelSync)
    await panelSync.installManagerCallbacks(manager)
    let ipcServer = IPCServer(manager: manager)
    let server = UnixSocketServer(socketPath: socketPath, ipcServer: ipcServer)

    try await server.start()

    await MainActor.run {
        let app = NSApplication.shared
        app.delegate = daemonDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
    fatalError("NSApplication.run() returned unexpectedly")
}
