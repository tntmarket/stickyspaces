import Darwin
import Foundation
import StickySpacesShared

public enum IPCSocketClientError: Error {
    case connectionFailed
    case writeFailed
    case readFailed
    case invalidResponse
}

public struct IPCSocketClient: Sendable {
    private let fd: Int32

    public init(socketPath: String) throws {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw IPCSocketClientError.connectionFailed
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { cStr in
            withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
                sunPath.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strncpy(dest, cStr, 103)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(fd)
            throw IPCSocketClientError.connectionFailed
        }

        self.fd = fd
    }

    public func send(_ request: IPCRequest) async throws -> IPCResponse {
        let line = try IPCWireCodec.encodeRequestLine(request)
        guard let data = line.data(using: .utf8) else {
            throw IPCSocketClientError.writeFailed
        }

        let written = data.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            return Darwin.write(fd, base, data.count)
        }
        guard written == data.count else {
            throw IPCSocketClientError.writeFailed
        }

        var buffer = Data()
        let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { readBuf.deallocate() }

        while true {
            let n = Darwin.read(fd, readBuf, 4096)
            guard n > 0 else { throw IPCSocketClientError.readFailed }
            buffer.append(readBuf, count: n)

            if let newlineIdx = buffer.firstIndex(of: 0x0A) {
                let lineData = Data(buffer[buffer.startIndex..<newlineIdx])
                guard let responseLine = String(data: lineData, encoding: .utf8) else {
                    throw IPCSocketClientError.invalidResponse
                }
                return try IPCWireCodec.decodeResponseLine(responseLine)
            }
        }
    }

    public func close() {
        Darwin.close(fd)
    }
}
