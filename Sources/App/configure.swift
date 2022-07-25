import Vapor
import NIOSSL

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
//    let homePath = app.directory.workingDirectory
//    let certPath = homePath + "/cert.pem"
//    let keyPath = homePath + "/key.pem"
//
//    let certs = try! NIOSSLCertificate.fromPEMFile(certPath).map {
//        NIOSSLCertificateSource.certificate($0)
//    }
//    let tls = TLSConfiguration.makeServerConfiguration(certificateChain: certs, privateKey: .file(keyPath))
    
    
    app.http.server.configuration = .init(hostname: "0.0.0.0",
                                          port: 8080
                                          // supportVersions: Set<HTTPVersionMajor>([.two]),
                                          // tlsConfiguration: tls
    )
    
    // register routes
    try routes(app)
    
    initializeDriveController()
}
