//
//  Movie.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import Vapor
import FluentSQLite
import Validation

final class Movie: CustomDebugStringConvertible {
    var id: Int?
    let movieID: String
    var title: String?
    var originalTitle: String?
    var duration: String?
    var ageRating: String?
    var genre: String?
    var country: String?
    var releaseDate: String?
    var plot: String?
    var poster: String?
    
    var showings = [Showing]()
    
    init(id: Int?, movieID: String, title: String?, originalTitle: String?, duration: String?, ageRating: String?, genre: String?, country: String?, releaseDate: String?, plot: String?, poster: String?) {
        
        self.id = id
        self.movieID = movieID
        self.title = title
        self.originalTitle = originalTitle
        self.duration = duration
        self.ageRating = ageRating
        self.genre = genre
        self.country = country
        self.releaseDate = releaseDate
        self.plot = plot
        self.poster = poster
    }
    
    convenience init(movieID: String) {
        self.init(id: nil, movieID: movieID, title: nil, originalTitle: nil, duration: nil, ageRating: nil, genre: nil, country: nil, releaseDate: nil, plot: nil, poster: nil)
    }
    
    var debugDescription: String {
        return """
        ---
        \(movieID)
        \(title)
        \(originalTitle)
        \(duration)
        \(ageRating)
        \(genre)
        \(country)
        \(releaseDate)
        \(plot)
        \(poster)
        \(showings)
        """
    }
}

extension Movie: SQLiteModel { }

extension Movie: Migration { }

extension Movie: Content { }
