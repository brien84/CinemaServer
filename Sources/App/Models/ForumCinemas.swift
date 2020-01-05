//
//  ForumCinemas.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import Vapor
import SwiftSoup

struct ForumCinemas {
    
    private let app: Application
    private let webClient: WebClient
    private let logger: Logger
    
    init(on app: Application) throws {
        self.app = app
        self.webClient = try WebClient(on: app)
        self.logger = try app.make(Logger.self)
    }
    
    func getMovies() -> Future<[Movie]> {
        return getRequestForms().flatMap { forms in

            let futureShowings = forms.map { form in
                self.getShowings(with: form)
            }.flatten(on: self.app).map { $0.flatMap { $0 } }

            return futureShowings.flatMap { showings in
                print(showings.count)

                let movies = self.createForumStubs(from: showings)

                print(movies.count)

                let futureMovies = movies.map { movie in
                    self.createMovie(from: movie)
                }.flatten(on: self.app).map { $0.compactMap { $0 } }

                let updatedMovies = futureMovies.map { movies in
                    movies.map { self.executeExceptions(on: $0) }
                }

                return updatedMovies.map { movies in

                    var filteredMovies = movies

                    return filteredMovies.compactMap { movie in

                        var moviesWithSameTitle = filteredMovies.filter {
                            $0.originalTitle == movie.originalTitle
                        }

                        filteredMovies.removeAll(where: { moviesWithSameTitle.contains($0) })

                        if moviesWithSameTitle.count > 1 {
                            let lastMovie = moviesWithSameTitle.popLast()
                            let showings = moviesWithSameTitle.flatMap { $0.showings }
                            lastMovie?.showings.append(contentsOf: showings)

                            return lastMovie!
                        } else if moviesWithSameTitle.count == 1 {
                            return movie
                        }

                        return nil
                    }
                }
            }
        }
    }
    
    /**
     Sends request with MovieID and parses rest of Movie info.
     
     - Returns: Movie or nil if parsing was unsuccessful.
     */

    private func createMovie(from stub: MovieStub) -> Future<Movie?> {
        return webClient.getHTML(from: "http://www.forumcinemas.lt/Event/\(stub.movieID)/").map { html in
            guard let doc: Document = try? SwiftSoup.parse(html) else { return nil }
            
            guard let title = doc.selectText("span[class='movieName']") else { return nil }
            
            var originalTitle = doc.selectText("div[style*='color: #666666; font-size: 13px; line-height: 15px;']")
            originalTitle = String((originalTitle?.dropLast(7))!)
            
            let duration = doc.selectText("[id='eventInfoBlock']>div>div:not([style]):not([class])")?.afterColon()
            let ageRating = doc.selectText("[id='eventInfoBlock']>*>[style*='float: none;']")?.afterColon()?.convertAgeRating()
            let plot = doc.selectText("div[class=contboxrow]:not([id])")
            
            let genre: String? = {
                guard let elements = try? doc.select("[id='eventInfoBlock']>*>[style='margin-top: 10px;']") else { return nil }
                // Maps text attributes from elements to an array, then finds text containing our string and returns it.
                return elements.compactMap { try? $0.text() }.first(where: { $0.contains("Žanras") })?.afterColon()
            }()
            
            // TEMP:
            let releaseDate = String(originalTitle!.suffix(6).dropLast(1).dropFirst(1))
            
//            movie.releaseDate = {
//                guard let elements = try? doc.select("[id='eventInfoBlock']>*>[style='margin-top: 10px;']") else { return nil }
//                // Maps text attributes from elements to an array, then finds text containing our string and returns it.
//                return elements.compactMap { try? $0.text() }.first(where: { $0.contains("Kino teatruose nuo") })?.afterColon()
//            }()
            
            let poster: String? = {
                guard let elements = try? doc.select("div[style='width: 97px; height: 146px; overflow: hidden;']>*") else { return nil }
                return try? elements.attr("src")
            }()
            
            let movie = Movie(id: nil, title: title, originalTitle: originalTitle, duration: duration, ageRating: ageRating, genre: genre, releaseDate: releaseDate, plot: plot, poster: poster, showings: stub.showings)
            
            return movie
            
        }.catch { error in
            self.logger.warning("update: \(error)")
        }
    }
    
    /**
     Reduces movieID and showing tuples to Movies.
     
     - Returns: Array of Movie, which only contain MovieID and Showings.
     */

    private func createForumStubs(from showings: [(movieID: String, showing: Showing)]) -> [MovieStub] {
        var result = [MovieStub]()
        
        showings.forEach { showing in
            if var stub = result.first(where: { $0.movieID == showing.movieID }) {
                stub.showings.append(showing.showing)
            } else {
                var newStub = MovieStub(movieID: showing.movieID)
                newStub.showings.append(showing.showing)
                result.append(newStub)
            }
        }
        
        return result
    }
    
    /**
     Sends RequestForm to host and parses response to get Showings and their corresponding movieIDs.
     
     - Returns: Array of tuple containing Showing and Showing's movieID.
     */
    
    private func getShowings(with form: RequestForm) -> Future<[(movieID: String, showing: Showing)]> {
        return webClient.getHTML(from: "http://www.forumcinemas.lt/", with: form).map { html in
            guard let doc: Document = try? SwiftSoup.parse(html) else { return [] }
            guard let items = try? doc.select("div[id*=showtime]") else { return [] }
            
            return items.flatMap { item -> [(String, Showing)] in
                guard let id = try? item.attr("id"), let movieID = id.findRegex(#"(?<=showTimes)\d*"#) else { return [] }
                
                return item.children().flatMap { child -> [(String, Showing)] in
                    guard let venue = try? child.select("div[style]").text().sanitizeVenue() else { return [] }
                    
                    return child.children().compactMap { child -> (String, Showing)? in
                        guard child.hasClass("showTime") else { return nil }
                        guard let time = try? child.text() else { return nil }
                        guard let date = "\(form.dt) \(time)".convertToDate() else { return nil }
                        guard let city = form.theatreArea.convertCity() else { return nil }
                        
                        return (movieID: movieID, showing: Showing(city: city, date: date, venue: venue))
                    }
                }
            }
        }
    }

    // MARK: - Showing parsing methods
    
    private struct MovieStub {
        let movieID: String
        var showings = [Showing]()
    }
    
    private struct RequestForm: Content {
        let theatreArea: String
        let dt: String
    }
    
    private enum OptionType {
        case area
        case date
    }

    /**
    Parses area options from ForumCinemas homepage, then loops through each area and parses dates.
     
    - Returns: RequestForm array with every area and date combination.
    */
    
    private func getRequestForms() -> Future<[RequestForm]> {
        return webClient.getHTML(from: "http://www.forumcinemas.lt/").flatMap { html in
            return self.parseOption(type: .area, from: html).map { area -> Future<[RequestForm]> in
                // Date is empty, because only area options are currently available
                let requestForm = RequestForm(theatreArea: area, dt: "")
                
                return self.webClient.getHTML(from: "http://www.forumcinemas.lt/", with: requestForm).map { html in
                    return self.parseOption(type: .date, from: html).map { date in
                        return RequestForm(theatreArea: area, dt: date)
                    }
                }.catch { error in
                    self.logger.warning("getRequestForms: \(error)")
                }
            }.flatten(on: self.app).map { return $0.flatMap { $0 } }
        }.catch { error in
            self.logger.warning("getRequestForms: \(error)")
        }
    }
    
    private func parseOption(type: OptionType, from html: String) -> [String] {
        guard let doc: Document = try? SwiftSoup.parse(html) else { return [] }
        let selector = type == OptionType.area ? "select[id='area']>option[value]" : "select[name='dt']>option[value]"
        guard let items = try? doc.select(selector) else { return [] }
        let values = items.compactMap { try? $0.attr("value") }
        
        return values
    }
}

extension ForumCinemas: DataExceptionable {
    func executeExceptions(on movie: Movie) -> Movie {
        guard let exceptions = readExceptions(for: "ForumCinemas") else { return movie }
        
        if let titleExceptions = exceptions["title"] as? [String : String] {
            for (key, value) in titleExceptions {
                movie.title = movie.title?.replacingOccurrences(of: key, with: value)
            }
        }
        
        if let originalTitleExceptions = exceptions["originalTitle"] as? [String : String] {
            for (key, value) in originalTitleExceptions {
                movie.originalTitle = movie.originalTitle?.replacingOccurrences(of: key, with: value)
            }
        }
        
        if let yearExceptions = exceptions["year"] as? [String : String] {
            for (movieTitle, year) in yearExceptions {
                if movie.originalTitle == movieTitle {
                    movie.releaseDate = year
                }
            }
        }
        
        return movie
    }
}

extension String {
    fileprivate func convertCity() -> String? {
        switch self {
        case "1011":
            return City.vilnius.rawValue
        case "1012":
            return City.kaunas.rawValue
        case "1014":
            return City.siauliai.rawValue
        case "1015":
            return City.klaipeda.rawValue
        default:
            return nil
        }
    }
    
    fileprivate func convertAgeRating() -> String? {
        switch self {
        case "Įvairaus amžiaus žiūrovams":
            return "V"
        case "N-7. Jaunesniems būtina suaugusiojo palyda":
            return "N-7"
        case "N-13. 7-12 m. vaikams būtina suaugusiojo palyda":
            return "N-13"
        case "Žiūrovams nuo 16 metų":
            return "N-16"
        case "Suaugusiems nuo 18 metų":
            return "N-18"
        default:
            return nil
        }
    }
    
    fileprivate func sanitizeVenue() -> String {
        return self
            .replacingOccurrences(of: " (Vilniuje)", with: "")
            .replacingOccurrences(of: " Kaune", with: "")
            .replacingOccurrences(of: " Klaipėdoje", with: "")
            .replacingOccurrences(of: " Šiauliuose", with: "")
    }
}
