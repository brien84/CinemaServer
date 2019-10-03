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
    private let logger: Logger
    private let webClient: WebClient
    
    init(on app: Application) throws {
        self.app = app
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }
    
    func getMovies() -> Future<[Movie?]> {
        return getMovieIDs().flatMap { ids in
            return ids.compactMap {
                
                return self.getMovie($0)
            }.flatten(on: self.app)
        }.catchMap { error in
            throw error
        }
    }
    
    private func getMovieIDs() -> Future<[String]> {
        return webClient.getHTML(from: "https://www.forumcinemas.lt/").map { html in
            guard let doc: Document = try? SwiftSoup.parse(html) else { return [] }
            guard let items = try? doc.select("select[name='Movies']>option[value]") else { return [] }
            
            return items.compactMap { try? $0.attr("value") }
        }
    }
    
    private func getMovie(_ id: String) -> Future<Movie?> {
        return webClient.getHTML(from: "http://www.forumcinemas.lt/Event/\(id)/").map { html in
            guard let doc: Document = try? SwiftSoup.parse(html) else { return nil }
            
            guard let title = doc.selectText("span[class='movieName']") else { return nil }
            let originalTitle = doc.selectText("div[style*='color: #666666; font-size: 13px; line-height: 15px;']")
            let duration = doc.selectText("[id='eventInfoBlock']>*>div>b", lastOccurrence: true)
            let ageRating = doc.selectText("[id='eventInfoBlock']>*>[style*='float: none;']")?.afterColon()?.convertAgeRating()
            let genre = doc.selectText("[id='eventInfoBlock']>*>[style='margin-top: 10px;']")?.afterColon()
            let country = doc.selectText("[id='eventInfoBlock']>*>*>[style='float: left; margin-right: 20px;']")?.afterColon()
            let releaseDate = doc.selectText("[id='eventInfoBlock']>*>[style='margin-top: 10px;']", lastOccurrence: true)?.afterColon()
            
            var poster: String? = nil
            if let elements = try? doc.select("div[style='width: 97px; height: 146px; overflow: hidden;']>*") {
                poster = try? elements.attr("src")
            }
            
            let plot = doc.selectText("div[class='contboxrow']>p")
            
            return Movie(id: nil,
                         movieID: id,
                         title: title.sanitizeTitle(),
                         originalTitle: originalTitle?.sanitizeTitle(),
                         duration: duration,
                         ageRating: ageRating,
                         genre: genre,
                         country: country,
                         releaseDate: releaseDate,
                         plot: plot,
                         poster: poster)
            
        }.catchMap { error -> Movie? in
            if let error = error as? URLError {
                self.logger.warning("ForumCinemas.getMovie with URL \(String(describing: error.failingURL)): \(error.localizedDescription)")
            } else {
                self.logger.warning("ForumCinemas.getMovie: \(error.localizedDescription)")
            }
            
            return nil
        }
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
    
    fileprivate func sanitizeTitle() -> String {
        return self
            .replacingOccurrences(of: " (dubbed)", with: "")
            .replacingOccurrences(of: " (dubliuotas)", with: "")
            .replacingOccurrences(of: " (OV)", with: "")
            .replacingOccurrences(of: " 3D", with: "")
            .replacingOccurrences(of: "LNK Kino Startas: ", with: "")
            .replacingOccurrences(of: "POWER HIT RADIO premjera: ", with: "")
    }
}
