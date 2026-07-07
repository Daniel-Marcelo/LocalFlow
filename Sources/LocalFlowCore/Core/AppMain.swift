import AppKit

/// Entry point called by the executable target's main.swift.
public enum AppMain {
    @MainActor
    public static func run() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--transcribe") || arguments.contains("--help") {
            // dispatchMain() (not a semaphore) keeps the main queue serviced
            // so MainActor hops inside the pipeline can run.
            Task.detached {
                exit(await PipelineCLI.run(arguments: arguments))
            }
            dispatchMain()
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
