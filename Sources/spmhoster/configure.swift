import Leaf
import NIOSSL
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
  // uncomment to serve files from /Public folder
  // Serves files from /Public folder
  // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

  // Allow uploads up to 500MB
  app.routes.defaultMaxBodySize = "500mb"

  // TLS Configuration
  let certPath = Environment.get("CERT_PATH") ?? app.directory.workingDirectory + "cert.pem"
  let keyPath = Environment.get("KEY_PATH") ?? app.directory.workingDirectory + "key.pem"

  do {
    let certificateChain = try NIOSSLCertificate.fromPEMFile(certPath).map {
      NIOSSLCertificateSource.certificate($0)
    }
    let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)

    app.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
      certificateChain: certificateChain,
      privateKey: .privateKey(privateKey)
    )
    app.logger.info("TLS enabled using certificates at \(certPath) and \(keyPath)")
  } catch {
    app.logger.warning("Could not load TLS certificates: \(error). Server will start in HTTP mode.")
  }

  app.views.use(.leaf)

  // register routes
  try routes(app)

  // Register custom serve command
  app.asyncCommands.use(ServeWithLimitCommand(), as: "serve", isDefault: true)
}
