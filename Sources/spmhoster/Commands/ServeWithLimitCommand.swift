import Vapor

struct ServeWithLimitCommand: AsyncCommand {
  struct Signature: CommandSignature {
    @Option(
      name: "max-artifacts-size", help: "Maximum size of the artifacts folder (e.g., 500MB, 1GB)")
    var maxSize: String?

    @Option(
      name: "artifacts-path", help: "Custom path for the artifacts folder.")
    var artifactsPath: String?

    @Option(name: "hostname", short: "H", help: "Set the hostname the server will run on.")
    var hostname: String?

    @Option(name: "port", short: "p", help: "Set the port the server will run on.")
    var port: Int?

    @Option(name: "bind", short: "b", help: "Bind to the given address (hostname:port).")
    var bind: String?
  }

  var help: String {
    "Serves the application with an optional artifact size limit."
  }

  func run(using context: CommandContext, signature: Signature) async throws {
    let app = context.application

    // Handle max artifacts size
    // Determine artifacts path
    let artifactsPath: String

    if let customPath = signature.artifactsPath {
      artifactsPath = customPath.hasSuffix("/") ? customPath : customPath + "/"
    } else {
      artifactsPath = app.directory.workingDirectory + "artifacts/"
    }

    // Handle max artifacts size
    var maxSizeBytes: Int?

    if let maxSizeString = signature.maxSize {
      if let bytes = SizeParser.parse(maxSizeString) {
        maxSizeBytes = bytes
        context.console.info("Artifact size limit set to: \(maxSizeString) (\(bytes) bytes)")
      } else {
        context.console.warning("Invalid format for --max-artifacts-size. Ignoring limit.")
      }
    }

    // Store configuration
    app.storage[ArtifactsConfigKey.self] = ArtifactsConfig(
      maxSizeBytes: maxSizeBytes,
      artifactsPath: artifactsPath
    )

    // Configure server address
    if let bind = signature.bind {
      let parts = bind.split(separator: ":")

      if parts.count == 2 {
        app.http.server.configuration.hostname = String(parts[0])

        if let port = Int(parts[1]) {
          app.http.server.configuration.port = port
        }
      }
    } else {
      if let hostname = signature.hostname {
        app.http.server.configuration.hostname = hostname
      }

      if let port = signature.port {
        app.http.server.configuration.port = port
      }
    }

    app.logger.notice("Artifacts location: \(artifactsPath)")

    try app.server.start()
    try await app.server.onShutdown.get()
  }
}

struct ArtifactsConfig {
  let maxSizeBytes: Int?
  let artifactsPath: String
}

struct ArtifactsConfigKey: StorageKey {
  typealias Value = ArtifactsConfig
}
