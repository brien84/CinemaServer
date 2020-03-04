//
//  Cinamon.swift
//  App
//
//  Created by Marius on 2020-03-02.
//

import Vapor

struct Cinamon: DataExceptionable {

    private(set) var keyIdentifier = "Cinamon"

    private let logger: Logger
    private let webClient: WebClient

    init(on app: Application) throws {
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }

    func getMovies() -> Future<[Movie]> {
        return webClient.getHTML(from: "https://cinamonkino.com/api/page/movies?cinema_id=77139293&timezone=Europe%2FTallinn&locale=lt").map { html in

            let cinamonService = try JSONDecoder().decode(CinamonService.self, from: html)

            let futureMovies = cinamonService.movies.compactMap { movie in
                return Movie(from: movie, on: cinamonService.screens)
            }

            return futureMovies.map { self.executeExceptions(on: $0) }

        }.catch { error in
            self.logger.warning("Cinamon.getMovies: \(error)")
        }
    }

}

extension Movie {

    fileprivate convenience init?(from movie: CinamonService.CinamonMovie, on screens: [String]) {

        guard let year: String = {
            guard let substring = movie.year?.split(separator: "-").first else { return nil }
            return String(substring)
        }() else { return nil }

        let duration: String? = {
            guard let movieDuration = movie.duration else { return nil }
            return String(movieDuration) + " min"
        }()

        let genres: [String]? = {
            guard let genre = movie.genre?.name else { return nil }
            return [genre]
        }()

        let plot: String? = {
            guard let plot = movie.plot else { return nil }
            return plot.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        }()

        let showings = movie.showings.compactMap { showing -> Showing? in
            if screens.contains(showing.screen_name) {
                return Showing(from: showing)
            } else {
                return nil
            }
        }

        self.init(id: nil,
                  title: movie.title,
                  originalTitle: movie.originalTitle,
                  year: year,
                  duration: duration,
                  ageRating: movie.ageRating,
                  genres: genres,
                  plot: plot,
                  poster: movie.poster,
                  showings: showings)
    }
}

extension Showing {

    fileprivate init?(from showing: CinamonService.CinamonMovie.CinamonShowing) {
        guard let date = showing.showtime.convertToDate() else { return nil }

        self.init(city: City.kaunas.rawValue, date: date, venue: "Cinamon", is3D: showing.is_3d)
    }
}


private struct CinamonService: Decodable {

    let movies: [CinamonMovie]
    let screens: [String]

    struct CinamonMovie: Decodable {
        let title: String
        let originalTitle: String
        let year: String?
        let duration: Int?
        let ageRating: String?
        let genre: Genre?
        let plot: String?
        let poster: String?
        let showings: [CinamonShowing]

        struct Genre: Decodable {
            let name: String
        }

        struct CinamonShowing: Decodable {
            let screen_name: String
            let showtime: String
            let is_3d: Bool
        }

        private enum CodingKeys: String, CodingKey {
            case title = "name"
            case originalTitle = "original_name"
            case year = "premiere_date"
            case duration = "runtime"
            case ageRating = "rating"
            case genre
            case plot = "synopsis"
            case poster
            case showings = "sessions"
        }
    }
}
