//
//  ForumCinemas.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import SwiftSoup
import Vapor

struct ForumCinemas: DataExceptionable {
    
    private(set) var keyIdentifier = "ForumCinemas"
    
    private let app: Application
    private let logger: Logger
    private let webClient: WebClient
    
    init(on app: Application) throws {
        self.app = app
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }
    
    func getMovies() -> Future<[Movie]> {
        return getRequestForms().flatMap { forms in

            let futureShowings = forms.map { form in
                self.getShowings(with: form)
            }.flatten(on: self.app).map { $0.flatMap { $0 } }
                        
            let futureMovies = futureShowings.flatMap { showings -> Future<[Movie]> in
                let movieStubs = self.createMovieStubs(from: showings)
                
                return movieStubs.map { stub in
                    self.createMovie(from: stub)
                }.flatten(on: self.app).map { $0.compactMap { $0 } }
            }
            
            return futureMovies.map { movies in
                return movies.map { self.executeExceptions(on: $0) }
            }
            
        }
    }
    
    /**
     Creates Movie from MovieStub object.
     
     - Returns: Movie or nil if parsing was unsuccessful.
     */

    private func createMovie(from stub: MovieStub) -> Future<Movie?> {
        return webClient.getHTML(from: "http://www.forumcinemas.lt/Event/\(stub.movieID)/").map { html in
            guard let doc: Document = try? SwiftSoup.parse(html) else { return nil }
            
            guard let title = doc.selectText("span[class='movieName']") else { return nil }
            
            guard let originalTitleWithYear = doc.selectText("div[style*='color: #666666; font-size: 13px; line-height: 15px;']") else { return nil }
            
            let originalTitle = String(originalTitleWithYear.dropLast(7))
            
            guard let year: String = {
                guard let year = originalTitleWithYear.findRegex(#"(?<=\()(\d{4})(?=\))"#) else { return nil }
                return String(year)
            }() else { return nil }
            
            let duration = doc.selectText("[id='eventInfoBlock']>div>div:not([style]):not([class])")?.afterColon()?.convertDurationToMinutes()
            let ageRating = doc.selectText("[id='eventInfoBlock']>*>[style*='float: none;']")?.afterColon()?.convertAgeRating()
            let plot = doc.selectText("div[class=contboxrow]:not([id])")
            
            let genres: [String]? = {
                guard let elements = try? doc.select("[id='eventInfoBlock']>*>[style='margin-top: 10px;']") else { return nil }
                // Maps text attributes from elements to an array, then finds text containing our string and returns it.
                let genreString = elements.compactMap { try? $0.text() }.first(where: { $0.contains("Žanras") })?.afterColon()
                
                return genreString?.replacingOccurrences(of: ", ", with: ",").split(separator: ",").map { $0.prefix(1).capitalized + $0.dropFirst() }
            }()
            
            let poster: String? = {
                guard let elements = try? doc.select("div[style='width: 97px; height: 146px; overflow: hidden;']>*") else { return nil }

                let attribute = try? elements.attr("src")

                let poster = attribute?.replacingOccurrences(of: "portrait_small", with: "portrait_medium").sanitizeHttp()
                
                if poster?.contains("https://") ?? false {
                    return poster
                } else {
                    return nil
                }
            }()
            
            return Movie(id: nil,
                         title: title,
                         originalTitle: originalTitle,
                         year: year,
                         duration: duration,
                         ageRating: ageRating,
                         genres: genres,
                         plot: plot,
                         poster: poster,
                         showings: stub.showings)
            
        }.catch { error in
            self.logger.warning("update: \(error)")
        }
    }
    
    /**
     Reduces movieID and showing tuples to array of MovieStub.
     
     - Returns: Array of MovieStub.
     */
    
    private class MovieStub {
        let movieID: String
        var showings = [Showing]()
        
        init(movieID: String) {
            self.movieID = movieID
        }
    }

    private func createMovieStubs(from showings: [(movieID: String, showing: Showing)]) -> [MovieStub] {
        var result = [MovieStub]()
        
        showings.forEach { showing in
            if let stub = result.first(where: { $0.movieID == showing.movieID }) {
                stub.showings.append(showing.showing)
            } else {
                let newStub = MovieStub(movieID: showing.movieID)
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
            
            guard let showingBlocks = try? doc.select("td[class*=result]") else { return [] }
            
            return showingBlocks.flatMap { block -> [(String, Showing)] in
                
                var is3D = false
                if let attribute3D = try? block.getElementsByAttributeValue("title", "3D") {
                    is3D = !attribute3D.isEmpty()
                }
                
                guard let items = try? block.select("div[id*=showtime]") else { return [] }
                
                return items.flatMap { item -> [(String, Showing)] in
                    guard let id = try? item.attr("id"), let movieID = id.findRegex(#"(?<=showTimes)\d*"#) else { return [] }
                    
                    return item.children().flatMap { child -> [(String, Showing)] in
                        guard let venue = try? child.select("div[style]").text().sanitizeVenue() else { return [] }
                        
                        return child.children().compactMap { child -> (String, Showing)? in
                            guard child.hasClass("showTime") else { return nil }
                            guard let time = try? child.text() else { return nil }
                            guard let date = "\(form.dt) \(time)".convertToDate() else { return nil }
                            guard let city = form.theatreArea.convertCity() else { return nil }
                            
                            return (movieID: movieID, showing: Showing(city: city, date: date, venue: venue, is3D: is3D))
                        }
                    }
                }
                
            }
        }
    }
    
    /**
    Parses area options from ForumCinemas homepage, then loops through each area and parses dates.
     
    - Returns: RequestForm array with every area and date combination.
    */
    
    private struct RequestForm: Content {
        let theatreArea: String
        let dt: String
    }
    
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
    
    private enum RequestOption {
        case area
        case date
    }
    
    private func parseOption(type: RequestOption, from html: String) -> [String] {
        guard let doc: Document = try? SwiftSoup.parse(html) else { return [] }
        let selector = type == RequestOption.area ? "select[id='area']>option[value]" : "select[name='dt']>option[value]"
        guard let items = try? doc.select(selector) else { return [] }
        let values = items.compactMap { try? $0.attr("value") }
        
        return values
    }
}

extension String {
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
    
    fileprivate func convertDurationToMinutes() -> String {
        let hoursString = self.split(separator: "h")[0]
        guard let hours = Int(hoursString) else { return self }
        
        let minutesString = self.split(separator: " ")[1].split(separator: "m")[0]
        guard let minutes = Int(minutesString) else { return self }
        
        let result = hours * 60 + minutes
    
        return ("\(result) min")
    }
    
    fileprivate func sanitizeVenue() -> String {
        return self
            .replacingOccurrences(of: " (Vilniuje)", with: "")
            .replacingOccurrences(of: " Kaune", with: "")
            .replacingOccurrences(of: " Klaipėdoje", with: "")
            .replacingOccurrences(of: " Šiauliuose", with: "")
    }
}
