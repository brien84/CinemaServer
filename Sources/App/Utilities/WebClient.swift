//
//  WebClient.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import Vapor

struct WebClient {
    private let app: Application
    private let client: Client
    
    init(on app: Application) throws {
        self.app = app
        self.client = try app.make(Client.self)
    }
    
    func getHTML(from url: String) -> Future<String> {
        return client.get(url).map { response in
            guard let responseData = response.http.body.data else { throw URLError(.badServerResponse) }
            guard let html = String(bytes: responseData, encoding: .utf8) else { throw URLError(.badServerResponse) }
            
            return html
        }
    }
}
