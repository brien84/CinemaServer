//
//  ForumCinemas.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import Vapor

struct ForumCinemas {
    
    let app: Application
    let logger: Logger
    let webClient: WebClient
    
    init(on app: Application) throws {
        self.app = app
        self.logger = try app.make(Logger.self)
        self.webClient = try WebClient(on: app)
    }
}
