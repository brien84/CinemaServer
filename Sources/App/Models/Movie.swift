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
    let localID: String
    let title: String
    let originalTitle: String?
    let runtime: String?
    let rated: String?
    let genre: String?
    let country: String?
    let released: String?
    let plot: String?
    let poster: String?
    
    init(id: Int?, localID: String, title: String, originalTitle: String?, runtime: String?, rated: String?, genre: String?, country: String?, released: String?, plot: String?, poster: String?) {
        
        self.id = id
        self.localID = localID
        self.title = title
        self.originalTitle = originalTitle
        self.runtime = runtime
        self.rated = rated
        self.genre = genre
        self.country = country
        self.released = released
        self.plot = plot
        self.poster = poster
    }
}

extension Movie: SQLiteModel { }

extension Movie: Migration { }

extension Movie: Content { }
