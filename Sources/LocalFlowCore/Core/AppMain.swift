import AppKit

/// Entry point called by the executable target's main.swift.
public enum AppMain {
    @MainActor
    public static func run() {
        configureMetalResources()
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

    /// whisper's SwiftPM resource accessor looks for `whisper_whisper.bundle`
    /// next to the main bundle (with a machine-specific `.build` fallback), so
    /// inside a packaged .app it finds nothing and ggml would silently fall
    /// back to CPU. Pointing GGML_METAL_PATH_RESOURCES at our Resources folder
    /// (which ships a self-contained `ggml-metal.metal`) lets ggml JIT-compile
    /// the shaders and keep the Metal backend. Dev runs from `.build` find a
    /// precompiled `default.metallib` in the SwiftPM bundle instead and skip
    /// the JIT; an already-set env var always wins.
    private static func configureMetalResources() {
        guard getenv("GGML_METAL_PATH_RESOURCES") == nil,
              let resources = Bundle.main.resourcePath,
              FileManager.default.fileExists(atPath: resources + "/ggml-metal.metal")
        else { return }
        setenv("GGML_METAL_PATH_RESOURCES", resources, 1)
    }
}
