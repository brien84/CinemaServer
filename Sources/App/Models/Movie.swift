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
    let title: String
    let originalTitle: String?
    let duration: String?
    let ageRating: String?
    let genre: String?
    let country: String?
    let releaseDate: String?
    let plot: String?
    let poster: String?
    
    init(id: Int?, movieID: String, title: String, originalTitle: String?, duration: String?, ageRating: String?, genre: String?, country: String?, releaseDate: String?, plot: String?, poster: String?) {
        
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
}

extension Movie: SQLiteModel { }

extension Movie: Migration { }

extension Movie: Content { }
