import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
  // uncomment to serve files from /Public folder
  // Serves files from /Public folder
  // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

  // Allow uploads up to 500MB
  app.routes.defaultMaxBodySize = "500mb"

  app.views.use(.leaf)

  // register routes
  try routes(app)

  // Register custom serve command
  app.asyncCommands.use(ServeWithLimitCommand(), as: "serve", isDefault: true)
}
