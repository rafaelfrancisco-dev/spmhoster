import Vapor

func routes(_ app: Application) throws {
  app.get { req async throws in
    try await req.view.render("index", ["title": "Hello Vapor!"])
  }

  app.get("hello") { req async -> String in
    "Hello, world!"
  }

  app.get("cert") { req async throws -> Response in
    guard let config = req.application.storage[CertConfigKey.self] else {
      throw Abort(.notFound, reason: "Certificate not configured or available")
    }
    return try await req.fileio.asyncStreamFile(at: config.certPath)
  }

  try app.register(collection: ArtifactController())
}
