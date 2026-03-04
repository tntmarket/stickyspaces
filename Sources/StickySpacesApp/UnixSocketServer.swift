import Darwin
import Foundation
import StickySpacesShared

public enum UnixSocketServerError: Error {
    case socketCreationFailed
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
}

public actor UnixSocketServer {
    private let socketPath: String
    private let ipcServer: IPCServer
    private var serverFD: Int32 = -1
    private var acceptTask: Task<Void, Never>?

    public init(socketPath: String, ipcServer: IPCServer) {
        self.socketPath = socketPath
        self.ipcServer = ipcServer
    }

    public func start() async throws {
        signal(SIGPIPE, SIG_IGN)
        unlink(socketPath)

        serverFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw UnixSocketServerError.socketCreationFailed
        }

        try bindToPath()

        guard Darwin.listen(serverFD, 5) == 0 else {
            let e = errno
            Darwin.close(serverFD)
            serverFD = -1
            throw UnixSocketServerError.listenFailed(errno: e)
        }

        let flags = fcntl(serverFD, F_GETFL)
        _ = fcntl(serverFD, F_SETFL, flags | O_NONBLOCK)

        let fd = serverFD
        let server = ipcServer
        acceptTask = Task {
            await Self.acceptLoop(serverFD: fd, ipcServer: server)
        }
    }

    public func shutdown() async {
        acceptTask?.cancel()
        acceptTask = nil
        if serverFD >= 0 {
            Darwin.close(serverFD)
            serverFD = -1
        }
        unlink(socketPath)
    }

    private func bindToPath() throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        setSunPath(&addr, socketPath)

        let fd = serverFD
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let e = errno
            Darwin.close(serverFD)
            serverFD = -1
            throw UnixSocketServerError.bindFailed(errno: e)
        }
    }

    private static func acceptLoop(serverFD: Int32, ipcServer: IPCServer) async {
        await withTaskGroup(of: Void.self) { group in
            while !Task.isCancelled {
                var clientAddr = sockaddr_un()
                var len = socklen_t(MemoryLayout<sockaddr_un>.size)
                let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                        Darwin.accept(serverFD, sockPtr, &len)
                    }
                }
                if clientFD >= 0 {
                    group.addTask {
                        await handleConnection(fd: clientFD, ipcServer: ipcServer)
                    }
                } else if errno == EAGAIN || errno == EWOULDBLOCK {
                    try? await Task.sleep(for: .milliseconds(5))
                } else {
                    break
                }
            }
            group.cancelAll()
        }
    }

    private static func handleConnection(fd: Int32, ipcServer: IPCServer) async {
        defer { Darwin.close(fd) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        var buffer = Data()
        let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { readBuf.deallocate() }

        while !Task.isCancelled {
            let n = Darwin.read(fd, readBuf, 4096)
            if n <= 0 { break }
            buffer.append(readBuf, count: n)

            while let newlineIdx = buffer.firstIndex(of: 0x0A) {
                let lineData = Data(buffer[buffer.startIndex..<newlineIdx])
                buffer = Data(buffer[buffer.index(after: newlineIdx)...])

                guard let line = String(data: lineData, encoding: .utf8) else { continue }
                let response = await ipcServer.handleLine(line)
                writeAll(fd: fd, string: response)
            }
        }
    }

    private static func writeAll(fd: Int32, string: String) {
        guard let data = string.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let n = Darwin.write(fd, base + offset, data.count - offset)
                if n <= 0 { break }
                offset += n
            }
        }
    }
}

private func setSunPath(_ addr: inout sockaddr_un, _ path: String) {
    path.withCString { cStr in
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
            sunPath.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                _ = strncpy(dest, cStr, 103)
            }
        }
    }
}
