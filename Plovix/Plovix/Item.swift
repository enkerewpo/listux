//
//  Item.swift
//  Plovix
//
//  Created by Mr wheatfox on 2025/3/26.
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
