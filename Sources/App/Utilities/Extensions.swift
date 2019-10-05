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
            print("String.findRegex: \(error.localizedDescription)")
            return nil
        }
    }
    
    func afterColon() -> String? {
        return self.components(separatedBy: ": ").last
    }
    
    func convertToDate() -> Date? {
        let dateFormatter = DateFormatter()
        
        // ForumCinemas format: 19.09.2019 11:00
        dateFormatter.dateFormat = "dd'.'MM'.'yyyy' 'HH':'mm"
        if let date = dateFormatter.date(from: self) {
            return date
        }
        
        // Multikino format: 2019-09-26T17:30:00
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss"
        if let date = dateFormatter.date(from: self) {
            return date
        }
    
        return nil
    }
}

// MARK: - SwiftSoup
extension Document {
    // 
    func selectText(_ selector: String, lastOccurrence: Bool = false) -> String? {
        guard let elements = try? self.select(selector) else { return nil }
        guard let element = lastOccurrence ? elements.last() : elements.first() else { return nil }
        return try? element.text()
    }
}
