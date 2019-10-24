//
//  Multikino.swift
//  App
//
//  Created by Marius on 03/10/2019.
//

import Foundation
import Vapor

struct Multikino {

    private let webClient: WebClient
    private let logger: Logger
    
    init(on app: Application) throws {
        self.webClient = try WebClient(on: app)
        self.logger = try app.make(Logger.self)
    }
    
    /**
     Decodes JSON from Multikino API to Movie info.
     
     - Returns: Array of Movie.
     */
    func getMovies() -> Future<[Movie]> {
        return webClient.getHTML(from: "https://multikino.lt/data/filmswithshowings/1001").map { html in
            guard let movieService = try? JSONDecoder().decode(MovieService.self, from: html) else { throw URLError(.cannotDecodeContentData) }

            return movieService.movies.compactMap { movie -> Movie? in
                
                if movie.showShowings == true {
                    let showings = movie.showings.flatMap { showing -> [Showing] in
                        return showing.times.compactMap { time in
                            guard let date = time.date.convertToDate() else { return nil }
                            
                            return Showing(city: City.vilnius.rawValue, date: date, venue: "Multikino")
                        }
                    }
                    
                    let newMovie = Movie(id: nil, movieID: movie.movieID, title: movie.title.sanitizeTitle(), originalTitle: movie.originalTitle?.sanitizeTitle(),
                                         duration: movie.duration, ageRating: movie.ageRating, genre: movie.genre, country: nil,
                                         releaseDate: movie.releaseDate, plot: movie.plot, poster: movie.poster)
                    
                    newMovie.showings.append(contentsOf: showings)
                    
                    return newMovie
                } else {
                    return nil
                }
            }
        }.catch { error in
            self.logger.warning("getMovies: \(error)")
        }
    }
}

// MARK: - Decodable helper

private struct MovieService: Decodable {
    let movies: [Movie]
    
    private enum CodingKeys: String, CodingKey {
        case movies = "films"
    }
    
    struct Movie: Decodable {
        let movieID: String
        private let fullTitle: String

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
    
        private struct Genres: Decodable {
            let names: [Genre]
            struct Genre: Decodable {
                let name: String
            }
        }
        
        private let genres: Genres?
        
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
        
        struct Showing: Decodable {
            let times: [Time]
            
            struct Time: Decodable {
                let date: String
            }
        }
        
        let showings: [Showing]
        let showShowings: Bool?
        
        private enum CodingKeys: String, CodingKey {
            case movieID = "id"
            case fullTitle = "title"
            case duration = "info_runningtime"
            case ageRating = "info_age"
            case genres
            case releaseDate = "info_release"
            case plot = "synopsis_short"
            case poster = "image_poster"
            case showings
            case showShowings = "show_showings"
        }
    }
}

extension String {
    fileprivate func sanitizeTitle() -> String {
        return self
            .replacingOccurrences(of: "MultiBabyKino: ", with: "")
            .replacingOccurrences(of: "MultiKinukas: ", with: "")
            .replacingOccurrences(of: "Multikinukas: ", with: "")
    }
}
