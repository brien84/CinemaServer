//
//  DataExceptionable.swift
//  App
//
//  Created by Marius on 2020-01-02.
//

import Foundation
import Vapor

protocol DataExceptionable {
    var keyIdentifier: String { get }

    func executeExceptions(on movie: Movie) -> Movie
}

extension DataExceptionable {
    func executeExceptions(on movie: Movie) -> Movie {
        guard let exceptions = readExceptions(for: keyIdentifier) else { return movie }

        if let titleExceptions = exceptions["title"] as? [String : String] {
            for (key, value) in titleExceptions {
                movie.title = movie.title.replacingOccurrences(of: key, with: value)
            }
        }
        
        if let originalTitleExceptions = exceptions["originalTitle"] as? [String : String] {
            for (key, value) in originalTitleExceptions {
                movie.originalTitle = movie.originalTitle.replacingOccurrences(of: key, with: value)
            }
        }

        if let posterExceptions = exceptions["poster"] as? [String : String] {
            for (key, value) in posterExceptions {
                movie.poster = movie.poster?.replacingOccurrences(of: key, with: value)
            }
        }
        
        return movie
    }
    
    private func readExceptions(for key: String) -> [String : AnyObject]? {
        let directory = DirectoryConfig.detect()
        let url = URL(fileURLWithPath: "\(directory.workDir)Public/Exceptions.plist")
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        let dictionary = try? PropertyListSerialization.propertyList(from: data,
                                                                     options: .mutableContainers,
                                                                     format: .none) as! [String : AnyObject]
        
        return dictionary?[key] as? [String : AnyObject]
    }
}
