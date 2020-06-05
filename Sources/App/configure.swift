import FluentSQLite
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register providers first
    try services.register(FluentSQLiteProvider())
    
    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    /// Configure a SQLite database
    let directoryConfig = DirectoryConfig.detect()
    let database = try SQLiteDatabase(storage: .file(path: "\(directoryConfig.workDir)movies.db"))
    
    /// Register the configured SQLite database to the database config
    var databases = DatabasesConfig()
    databases.add(database: database, as: .sqlite)
    services.register(databases)
    
    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: Movie.self, database:  DatabaseIdentifier<Movie.Database>.sqlite)
    services.register(migrations)
}
