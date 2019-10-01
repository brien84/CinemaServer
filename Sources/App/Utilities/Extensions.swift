//
//  Extensions.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import Foundation
import SwiftSoup

extension String {
    func findRegex(_ regex: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            
            guard let match = results.first else { return nil }
            
            return Range(match.range, in: self).map { String(self[$0]) }
        } catch {
            print("find(regex, in text): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - SwiftSoup
extension Document {
    func selectText(with selector: String, lastOccurrence: Bool = false) -> String? {
        guard let elements = try? self.select(selector) else { return nil }
        guard let element = lastOccurrence ? elements.last() : elements.first() else { return nil }
        return try? element.text()
    }
}
