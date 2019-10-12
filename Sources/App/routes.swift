import Vapor

public func routes(_ router: Router) throws {
    
    router.get("movies") { req -> Future<[Movie]> in
        return Movie.query(on: req).all()
    }
}
