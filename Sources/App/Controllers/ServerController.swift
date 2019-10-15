//
//  ServerController.swift
//  App
//
//  Created by Marius on 30/09/2019.
//

import Vapor
import FluentSQLite

final class ServerController {
    
    private let app: Application
    private let logger: Logger
    private let conn: SQLiteConnection
    
    private let forum: ForumCinemas
    private let multi: Multikino

    init(on app: Application) throws {
        self.app = app
        self.conn = try app.newConnection(to: .sqlite).wait()
        self.logger = try app.make(Logger.self)
        
        self.forum = try ForumCinemas(on: app)
        self.multi = try Multikino(on: app)
    }
    
    func start() {
        app.eventLoop.scheduleTask(in: TimeAmount.seconds(3600), start)
        update()
    }
    
    private func update() {
        self.logger.info("Update is starting!")
        
        // Transaction executes only if all futures return successfully!
        let futureTransaction = conn.transaction(on: .sqlite) { conn -> Future<Void> in
            return Movie.query(on: self.conn).delete().flatMap {
                return self.getMovies().flatMap { movies in
                    return movies.map {
                        $0.save(on: self.conn).transform(to: .done(on: self.conn))
                    }.flatten(on: self.conn)
                }
            }
        }

        futureTransaction.do { _ in
            self.logger.info("Update is complete!")
        }.catch { error in
            self.logger.warning("update: \(error)")
        }
    }
    
    private func getMovies() -> Future<[Movie]> {
        return forum.getMovies().flatMap { forumMovies in
            return self.multi.getMovies().map { multiMovies in
                
                var movies = forumMovies
                
                multiMovies.forEach { multiMovie in
                    // If movie with the same title as multiMovie is found in forumMovies...
                    if let movie = movies.first(where: { $0.title?.lowercased() == multiMovie.title?.lowercased() }) {
                        // add multiMovie's showings to forumMovie
                        movie.showings.append(contentsOf: multiMovie.showings)
                    } else {
                        // add multiMovie to forumMovies
                        movies.append(multiMovie)
                    }
                }
                
                return movies
            }
        }
    }
}
