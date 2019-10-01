import Vapor

/// Called after your application has initialized.
public func boot(_ app: Application) throws {

    let server = try ServerController(on: app)
    server.start()
}
