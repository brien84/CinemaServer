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

}

extension URL {
    var fileNameWithoutExtension: String {
        self.deletingPathExtension().lastPathComponent
    }

    var fileNameWithExtension: String {
        self.lastPathComponent
    }
}
