//
//  Item.swift
//  orbit
//
//  Created by Alexander Korte on 1/9/26.
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
