//
//  AnimalType.swift
//  Application
//
//  Created by Denis Bystruev on 03/09/2019.
//

import Foundation
import SwiftKueryORM

enum AnimalType: Int, Codable {
    case dog
    case cat
    case rabbit
    case turtle
    
    var emoji: Character {
        switch self {
        case .dog:
            return "🐶"
        case .cat:
            return "🐱"
        case .rabbit:
            return "🐰"
        case .turtle:
            return "🐢"
        }
    }
}

extension AnimalType: Model {}
