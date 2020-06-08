//
//  Validator.swift
//  App
//
//  Created by Marius on 2020-06-08.
//

import Foundation
import Vapor

struct Validator {

    private var baseURL = URL(string: "https://movies.ioys.lt/posters/")

    private lazy var posterPaths: [URL]? = {
        let directory = URL(fileURLWithPath: "\(DirectoryConfig.detect().workDir)Public/Posters")
        return try? FileManager().contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    }()

    mutating func setPoster(for movie: Movie) -> Movie {
        if let posterPath = posterPaths?.first(where: { $0.fileNameWithoutExtension == movie.originalTitle }) {
            let url = baseURL?.appendingPathComponent(posterPath.fileNameWithExtension)
            movie.poster = url?.absoluteString
        } else {
            movie.poster = nil
            print(movie.originalTitle)
        }

        return movie
    }

    func setPlot(for movie: Movie) -> Movie {
        let plist = URL(fileURLWithPath: "\(DirectoryConfig.detect().workDir)Public/Plots.plist")
        guard let data = try? Data(contentsOf: plist) else { return movie }

        guard let dictionary = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: .none) as! [String: String]
            else { return movie }

        guard let key = (dictionary.keys.first { $0 == movie.originalTitle }) else { return movie }
        guard let plot = dictionary[key] else { return movie }

        movie.plot = plot
        print(movie.originalTitle)

        return movie
    }

}

extension URL {
    var fileNameWithoutExtension: String {
        self.deletingPathExtension().lastPathComponent
    }

    var fileNameWithExtension: String {
        self.lastPathComponent
    }
}
