//
//  ResponseType.swift
//  Application
//
//  Created by Denis Bystruev on 03/09/2019.
//

import SwiftKueryORM

enum ResponseType: Int, Codable {    
    case single, multiple, ranged
}

extension ResponseType: Model {}
