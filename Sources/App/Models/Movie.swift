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
    var title: String
    var originalTitle: String
    var duration: String?
    var ageRating: String?
    var genre: String?
    var year: String?
    var plot: String?
    var poster: String?
    var showings: [Showing]
    
    init(id: Int?, title: String, originalTitle: String, duration: String?, ageRating: String?, genre: String?, year: String?, plot: String?, poster: String?, showings: [Showing]) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.duration = duration
        self.ageRating = ageRating
        self.genre = genre
        self.year = year
        self.plot = plot
        self.poster = poster
        self.showings = showings
    }
}

extension Movie: SQLiteModel { }

extension Movie: Migration { }

extension Movie: Content { }

extension Movie: Equatable {
    static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.originalTitle.lowercased() == rhs.originalTitle.lowercased()
    }
}
