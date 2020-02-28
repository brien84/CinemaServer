//
//  ServerController.swift
//  App
//
//  Created by Marius on 30/09/2019.
//

import FluentSQLite
import Vapor

final class ServerController {
    
    private let app: Application
    private let conn: SQLiteConnection
    private let logger: Logger
    
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
        app.eventLoop.scheduleTask(in: TimeAmount.seconds(43200), start)
        update()
    }
    
    private func update() {
        logger.info("Update is starting!")
    
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
        
        let forumFutures = forum.getMovies()
        let multiFutures = multi.getMovies()
        
        return forumFutures.and(multiFutures).map { forumMovies, multiMovies in
            
            let forumMovies = self.merge(movies: forumMovies)
            let multiMovies = self.merge(movies: multiMovies)
            
            let movies = self.merge(movies: multiMovies, to: forumMovies)
            
            return movies
        }
    }
    
    private func merge(movies: [Movie], to result: [Movie] = [Movie]()) -> [Movie] {
        var result = result
        
        movies.forEach { movie in
            if let resultMovie = result.first(where: { $0 == movie }) {
                resultMovie.showings.append(contentsOf: movie.showings)
            } else {
                result.append(movie)
            }
        }
        
        return result
    }
}
