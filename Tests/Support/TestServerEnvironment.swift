import Foundation
@testable import StickySpacesApp
@testable import StickySpacesShared

struct TestServerEnvironment: Sendable {
    let socketPath: String
    let server: UnixSocketServer

    init() async throws {
        socketPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).sock").path

        let store = StickyStore()
        let yabai = FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 1))
        let panelSync = InMemoryPanelSync()
        let manager = StickyManager(store: store, yabai: yabai, panelSync: panelSync)
        let ipcServer = IPCServer(manager: manager)
        server = UnixSocketServer(socketPath: socketPath, ipcServer: ipcServer)
        try await server.start()
    }

    func shutdown() async {
        await server.shutdown()
    }
}
