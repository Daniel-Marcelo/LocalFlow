import AppKit

/// Entry point called by the executable target's main.swift.
public enum AppMain {
    @MainActor
    public static func run() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--transcribe") || arguments.contains("--help") {
            let semaphore = DispatchSemaphore(value: 0)
            var exitCode: Int32 = 0
            Task {
                exitCode = await PipelineCLI.run(arguments: arguments)
                semaphore.signal()
            }
            semaphore.wait()
            exit(exitCode)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
