//
//  ServerController.swift
//  App
//
//  Created by Marius on 30/09/2019.
//

import Vapor

final class ServerController {
    
    let app: Application
    let logger: Logger
    
    init(on app: Application) throws {
        self.app = app
        self.logger = try app.make(Logger.self)
    }
    
    func start() {

    }
}
