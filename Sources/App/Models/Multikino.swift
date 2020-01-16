//
//  Multikino.swift
//  App
//
//  Created by Marius on 03/10/2019.
//

import Vapor

struct Multikino: DataExceptionable {
    
    private(set) var keyIdentifier = "Multikino"

    private let logger: Logger
    private let webClient: WebClient
    
    init(on app: Application) throws {
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }
    
    /**
     Decodes JSON from Multikino API to Movie info.
     
     - Returns: Array of Movie.
     */
    
    func getMovies() -> Future<[Movie]> {
        return webClient.getHTML(from: "https://multikino.lt/data/filmswithshowings/1001").map { html in
            
            let multiService = try JSONDecoder().decode(MultikinoService.self, from: html)

            let futureMovies = multiService.movies.compactMap { movie in
                return Movie(from: movie)
            }
            
            return futureMovies.map { self.executeExceptions(on: $0) }
            
        }.catch { error in
            self.logger.warning("Multikino.getMovies: \(error)")
        }
    }
}

extension Movie {
    fileprivate convenience init?(from movie: MultikinoService.MultikinoMovie) {

        guard movie.showShowings == true else { return nil }

        let title = movie.title.findRegex(#"^.*?(?=\s\()"#) ?? movie.title
        
        let originalTitle = movie.title.findRegex(#"(?<=\()(.*?)(?=\))"#) ?? movie.title
  
        guard let year: String = {
            guard let yearSubstring = movie.year.split(separator: ".").last else { return nil }
            return String(yearSubstring)
        }() else { return nil }
        
        let duration = movie.duration.replacingOccurrences(of: ".", with: "")
        
        let genre = movie.genres.names.map { $0.name }

        let showings = movie.showings.flatMap { showing in
            return showing.times.compactMap { time in
                return Showing(from: time)
            }
        }
        
        let poster = movie.poster.sanitizeHttp()
        
        self.init(id: nil,
                  title: title,
                  originalTitle: originalTitle,
                  year: year,
                  duration: duration,
                  ageRating: movie.ageRating,
                  genre: genre,
                  plot: movie.plot,
                  poster: poster,
                  showings: showings)
    }
}

extension Showing {
    fileprivate init?(from time: MultikinoService.MultikinoMovie.MultikinoShowing.Time) {
        guard let date = time.date.convertToDate() else { return nil }
        let is3D = time.screen_type == "3D" ? true : false
        
        self.init(city: City.vilnius.rawValue, date: date, venue: "Multikino", is3D: is3D)
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
        let year: String
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
            case year = "info_release"
            case plot = "synopsis_short"
            case poster = "image_poster"
            case genres
            case showShowings = "show_showings"
            case showings
        }
        
    }
}
