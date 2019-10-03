//
//  Multikino.swift
//  App
//
//  Created by Marius on 03/10/2019.
//

import Foundation
import Vapor

struct Multikino {
    
    private let app: Application
    private let logger: Logger
    private let webClient: WebClient
    
    init(on app: Application) throws {
        self.app = app
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }
    
    func getMovies() -> Future<[Movie]> {
        return webClient.getHTML(from: "https://multikino.lt/data/filmswithshowings/1001").map { html in
            
            guard let movieService = try? JSONDecoder().decode(MovieService.self, from: html) else { throw URLError(.cannotDecodeContentData) }
            
            return movieService.movies.compactMap { movie -> Movie? in
                if movie.showShowings == true {
                    return Movie(id: nil,
                                 movieID: movie.movieID,
                                 title: movie.title.sanitizeTitle(),
                                 originalTitle: movie.originalTitle,
                                 duration: movie.duration,
                                 ageRating: movie.ageRating,
                                 genre: movie.genre,
                                 country: nil,
                                 releaseDate: movie.releaseDate,
                                 plot: movie.plot,
                                 poster: movie.poster)
                } else {
                    return nil
                }
            }
        }
    }
}

// MARK: - Decodable helpers

private struct MovieService: Decodable {
    let movies: [Movie]
    
    private enum CodingKeys: String, CodingKey {
        case movies = "films"
    }
    
    struct Movie: Decodable {
        private struct Genres: Decodable {
            let names: [Genre]
            struct Genre: Decodable {
                let name: String
            }
        }
        
        private let genres: Genres?
        private let fullTitle: String
        let localLink: String?
        let showShowings: Bool?
        let movieID: String
        
        var title: String {
            return fullTitle.findRegex(#"^.*?(?=\s\()"#) ?? fullTitle
        }
        
        var originalTitle: String? {
            guard let year = releaseDate?.split(separator: ".").last else { return nil }
            let title = fullTitle.findRegex(#"(?<=\()(.*?)(?=\))"#) ?? fullTitle
            return "\(title) (\(year))"
        }
        
        let duration: String?
        let ageRating: String?
        
        var genre: String? {
            guard let genres = genres else { return nil }
            var genre = ""
            genres.names.forEach {
                genre.append(contentsOf: "\($0.name), ")
            }
            genre = String(genre.dropLast(2))
            return genre
        }
        
        let releaseDate: String?
        let plot: String?
        let poster: String?
        
        private enum CodingKeys: String, CodingKey {
            case genres
            case fullTitle = "title"
            case localLink = "filmlink"
            case showShowings = "show_showings"
            case movieID = "id"
            case duration = "info_runningtime"
            case ageRating = "info_age"
            case releaseDate = "info_release"
            case plot = "synopsis_short"
            case poster = "image_poster"
        }
    }
}

extension String {
    fileprivate func sanitizeTitle() -> String {
        return self
            .replacingOccurrences(of: "MultiBabyKino: ", with: "")
            .replacingOccurrences(of: "MultiKinukas: ", with: "")
    }
}
