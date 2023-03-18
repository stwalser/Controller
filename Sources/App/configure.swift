import Vapor
import NIOSSL

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.http.server.configuration = .init(hostname: "0.0.0.0", port: 8080)
    
    // register routes
    try routes(app)
    
    initializeDriveController()
}
