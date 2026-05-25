//
//  Item.swift
//  Stryde
//
//  Created by Besart Memeti on 25.05.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
