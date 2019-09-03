//
//  Question.swift
//  Application
//
//  Created by Denis Bystruev on 03/09/2019.
//

import Foundation
import SwiftKueryORM

struct Question: Codable {
    var id: Int?
    var text: String?
    var type: Int?
    var answerId: Int?
}

extension Question: Model {}
