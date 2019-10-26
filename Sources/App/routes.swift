import Vapor

public func routes(_ router: Router) throws {
    
    router.get("all") { req -> Future<[Movie]> in
        return Movie.query(on: req).all()
    }
}
