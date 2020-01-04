//
//  DataExceptionable.swift
//  App
//
//  Created by Marius on 2020-01-02.
//

import Foundation
import Vapor

protocol DataExceptionable {
    func readExceptions(for key: String) -> [String : AnyObject]?
    func executeExceptions(on movie: Movie) -> Movie
}

extension DataExceptionable {
    func readExceptions(for key: String) -> [String : AnyObject]? {
        let directory = DirectoryConfig.detect()
        let url = URL(fileURLWithPath: "\(directory.workDir)Public/Exceptions.plist")
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        let dictionary = try? PropertyListSerialization.propertyList(from: data,
                                                                     options: .mutableContainers,
                                                                     format: .none) as! [String : AnyObject]
        
        return dictionary?[key] as? [String : AnyObject]
    }
}
