import AppKit
import Foundation
import StickySpacesShared

@main
struct StickySpacesMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.first == "--daemon" {
            Task { @MainActor in
                do {
                    try await bootstrapDaemon()
                } catch {
                    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
                    Foundation.exit(1)
                }
            }

            let app = NSApplication.shared
            app.delegate = daemonDelegate
            app.setActivationPolicy(.accessory)
            app.run()
            fatalError("NSApplication.run() returned unexpectedly")
        }

        var cliResult: Result<String, Error>?

        Task {
            do {
                cliResult = .success(
                    try await CLIClientRunner.run(args: args, socketPath: DaemonPaths.socketPath)
                )
            } catch {
                cliResult = .failure(error)
            }
            CFRunLoopStop(CFRunLoopGetMain())
        }
        CFRunLoopRun()

        switch cliResult {
        case .success(let output):
            FileHandle.standardOutput.write(Data(output.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        case .failure(let error):
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            Foundation.exit(1)
        case .none:
            Foundation.exit(1)
        }
    }
}
