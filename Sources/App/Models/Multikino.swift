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
            
            let multiService = try JSONDecoder().decode(MultikinoService.self, from: html)

            return multiService.movies.compactMap { movie in
                return Movie(from: movie)
            }
            
        }.catch { error in
            self.logger.warning("Multikino.getMovies: \(error)")
        }
    }
}

extension Movie {
    fileprivate convenience init?(from movie: MultikinoService.MultikinoMovie) {

        guard movie.showShowings == true else { return nil }

        let title = movie.title.findRegex(#"^.*?(?=\s\()"#) ?? movie.title

        guard let originalTitle: String = {
            guard let year = movie.releaseDate.split(separator: ".").last else { return nil }
            let title = movie.title.findRegex(#"(?<=\()(.*?)(?=\))"#) ?? movie.title
            return "\(title) (\(year))"
        }() else { return nil }
        
        let genre: String = {
            let genre = movie.genres.names.reduce(into: "") { result, genre in
                result.append(contentsOf: "\(genre), ")
            }
            
            return String(genre.dropLast(2))
        }()
        
        let showings = movie.showings.flatMap { showing in
            return showing.times.compactMap { time in
                return Showing(from: time)
            }
        }
        
        self.init(id: nil,
                  movieID: "",
                  title: title.sanitizeTitle(),
                  originalTitle: originalTitle.sanitizeTitle(),
                  duration: movie.duration,
                  ageRating: movie.ageRating,
                  genre: genre,
                  country: nil,
                  releaseDate: movie.releaseDate,
                  plot: movie.plot,
                  poster: movie.poster,
                  showings: showings)
    }
}

extension Showing {
    fileprivate init?(from time: MultikinoService.MultikinoMovie.MultikinoShowing.Time) {
        guard let date = time.date.convertToDate() else { return nil }
        
        self.init(city: City.vilnius.rawValue, date: date, venue: "Multikino")
    }
}

private struct MultikinoService: Decodable {
    
    let movies: [MultikinoMovie]
    
    private enum CodingKeys: String, CodingKey {
        case movies = "films"
    }
    
    struct MultikinoMovie: Decodable {
        
        let title: String
        let duration: String
        let ageRating: String
        let releaseDate: String
        let plot: String?
        let poster: String
        let genres: Genres
        let showShowings: Bool
        let showings: [MultikinoShowing]
        
        struct Genres: Decodable {
            let names: [Genre]
            
            struct Genre: Decodable {
                let name: String
            }
        }
        
        struct MultikinoShowing: Decodable {
            let times: [Time]
            
            struct Time: Decodable {
                let screen_type: String
                let date: String
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case title
            case duration = "info_runningtime"
            case ageRating = "info_age"
            case releaseDate = "info_release"
            case plot = "synopsis_short"
            case poster = "image_poster"
            case genres
            case showShowings = "show_showings"
            case showings
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
