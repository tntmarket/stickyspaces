import Foundation
import StickySpacesShared

@main
struct StickySpacesMain {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.first == "--daemon" {
            do {
                try await startDaemon()
            } catch {
                FileHandle.standardError.write(Data("error: \(error)\n".utf8))
                Foundation.exit(1)
            }
        }

        do {
            let output = try await CLIClientRunner.run(args: args, socketPath: DaemonPaths.socketPath)
            FileHandle.standardOutput.write(Data(output.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }
}
