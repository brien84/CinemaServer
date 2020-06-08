import Vapor

public func routes(_ router: Router) throws {
    
    router.get("all") { req -> Future<[Movie]> in
        return Movie.query(on: req).all()
    }

    router.get("posters", String.parameter) { req -> Future<Response> in
        let fileName = try req.parameters.next(String.self)
        let path = try req.make(DirectoryConfig.self).workDir + "Public/Posters/" + fileName

        return try req.streamFile(at: path)
    }

}
