//
//  OMDB.swift
//  App
//
//  Created by Marius on 2019-12-29.
//

import Vapor

struct OMDB {
    
    private let logger: Logger
    private let webClient: WebClient
    
    init(on app: Application) throws {
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }
    
    func updatePoster(for movie: Movie) -> Future<Movie> {
        let query = OMDBQuery(t: movie.originalTitle, y: movie.year)
        
        return webClient.getHTML(from: "http://www.omdbapi.com/", with: query).map { html in
            
            guard let omdb = try? JSONDecoder().decode(omdbService.self, from: html) else { return movie }
            
            if omdb.poster.contains("https://") {
                movie.poster = omdb.poster.replacingOccurrences(of: "SX300", with: "SX600")
            } else {
                movie.poster = nil
            }
            
            return movie
        }
    }
}

private struct OMDBQuery: Content {
    let t: String
    let y: String
    let type = "movie"
    let plot = "full"
    let apikey = "6c1a4f5b"
}

private struct omdbService: Decodable {
    let poster: String
    
    private enum CodingKeys: String, CodingKey {
        case poster = "Poster"
    }
}
