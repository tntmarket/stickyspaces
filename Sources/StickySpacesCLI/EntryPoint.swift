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

        let app = makeAppFromEnvironment()

        do {
            let output = try await StickySpacesCLICommandRunner.run(args: args, app: app)
            FileHandle.standardOutput.write(Data(output.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func makeAppFromEnvironment() -> DemoApp {
        if ProcessInfo.processInfo.environment["STICKYSPACES_SIMULATE_YABAI_UNAVAILABLE"] == "1" {
            return DemoAppFactory.makeWithUnavailableYabai()
        }
        return DemoAppFactory.makeReady()
    }
}
