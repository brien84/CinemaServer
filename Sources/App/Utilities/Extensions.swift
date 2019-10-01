//
//  Extensions.swift
//  App
//
//  Created by Marius on 01/10/2019.
//

import SwiftSoup

// MARK: - SwiftSoup
extension Document {
    func selectText(with selector: String, lastOccurrence: Bool = false) -> String? {
        guard let elements = try? self.select(selector) else { return nil }
        guard let element = lastOccurrence ? elements.last() : elements.first() else { return nil }
        return try? element.text()
    }
}
