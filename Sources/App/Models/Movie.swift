//
//  Movie.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import Vapor
import FluentSQLite
import Validation

final class Movie {
    var id: Int?
    let movieID: String
    var title: String?
    var originalTitle: String?
    var duration: String?
    var ageRating: String?
    var genre: String?
    var releaseDate: String?
    var plot: String?
    var poster: String?
    var showings: [Showing]
    
    init(id: Int?, movieID: String, title: String?, originalTitle: String?, duration: String?, ageRating: String?, genre: String?, releaseDate: String?, plot: String?, poster: String?, showings: [Showing]) {
        
        self.id = id
        self.movieID = movieID
        self.title = title
        self.originalTitle = originalTitle
        self.duration = duration
        self.ageRating = ageRating
        self.genre = genre
        self.releaseDate = releaseDate
        self.plot = plot
        self.poster = poster
        self.showings = showings
    }
    
    convenience init(movieID: String) {
        self.init(id: nil, movieID: movieID, title: nil, originalTitle: nil, duration: nil, ageRating: nil, genre: nil, releaseDate: nil, plot: nil, poster: nil, showings: [])
    }
}

extension Movie: SQLiteModel { }

extension Movie: Migration { }

extension Movie: Content { }

extension Movie: Equatable {
    static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.originalTitle?.lowercased() == rhs.originalTitle?.lowercased()
    }
}
