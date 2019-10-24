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
                let movies = self.createMovies(from: showings)
                
                let futureMovies = movies.map { movie in
                    self.update(movie)
                }.flatten(on: self.app).map { $0.compactMap { $0 } }
                
                return futureMovies
            }
        }
    }
    
    /**
     Sends request with MovieID and parses rest of Movie info.
     
     - Returns: Movie or nil if parsing was unsuccessful.
     */
    private func update(_ movie: Movie) -> Future<Movie?> {
        return webClient.getHTML(from: "http://www.forumcinemas.lt/Event/\(movie.movieID)/").map { html in
            guard let doc: Document = try? SwiftSoup.parse(html) else { return nil }
            
            guard let title = doc.selectText("span[class='movieName']") else { return nil }
            movie.title = title.sanitizeTitle()
            
            movie.originalTitle = doc.selectText("div[style*='color: #666666; font-size: 13px; line-height: 15px;']")?.sanitizeTitle()
            movie.duration = doc.selectText("[id='eventInfoBlock']>div>div:not([style]):not([class])")?.afterColon()
            movie.ageRating = doc.selectText("[id='eventInfoBlock']>*>[style*='float: none;']")?.afterColon()?.convertAgeRating()
            movie.country = doc.selectText("[id='eventInfoBlock']>*>*>[style='float: left; margin-right: 20px;']")?.afterColon()
            movie.plot = doc.selectText("div[class=contboxrow]:not([id])")
            
            movie.genre = {
                guard let elements = try? doc.select("[id='eventInfoBlock']>*>[style='margin-top: 10px;']") else { return nil }
                // Maps text attributes from elements to an array, then finds text containing our string and returns it.
                return elements.compactMap { try? $0.text() }.first(where: { $0.contains("Žanras") })?.afterColon()
            }()
            
            movie.releaseDate = {
                guard let elements = try? doc.select("[id='eventInfoBlock']>*>[style='margin-top: 10px;']") else { return nil }
                // Maps text attributes from elements to an array, then finds text containing our string and returns it.
                return elements.compactMap { try? $0.text() }.first(where: { $0.contains("Kino teatruose nuo") })?.afterColon()
            }()
            
            movie.poster = {
                guard let elements = try? doc.select("div[style='width: 97px; height: 146px; overflow: hidden;']>*") else { return nil }
                return try? elements.attr("src")
            }()
            
            return movie
        }.catch { error in
            self.logger.warning("update: \(error)")
        }
    }
    
    /**
     Reduces movieID and showing tuples to Movies.
     
     - Returns: Array of Movie, which only contain MovieID and Showings.
     */
    private func createMovies(from showings: [(movieID: String, showing: Showing)]) -> [Movie] {
        var result = [Movie]()
        
        showings.forEach { showing in
            if let movie = result.first(where: { $0.movieID == showing.movieID }) {
                movie.showings.append(showing.showing)
            } else {
                let newMovie = Movie(movieID: showing.movieID)
                newMovie.showings.append(showing.showing)
                result.append(newMovie)
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
    
    fileprivate func sanitizeTitle() -> String {
        return self
            .replacingOccurrences(of: " (dubbed)", with: "")
            .replacingOccurrences(of: " (dubliuotas)", with: "")
            .replacingOccurrences(of: " (OV)", with: "")
            .replacingOccurrences(of: " 3D", with: "")
            .replacingOccurrences(of: "LNK Kino Startas: ", with: "")
            .replacingOccurrences(of: "POWER HIT RADIO premjera: ", with: "")
            .replacingOccurrences(of: "ZIP FM premjera: ", with: "")
            .replacingOccurrences(of: "TV3 premjera: ", with: "")
    }
}
