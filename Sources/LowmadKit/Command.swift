//
//  Command.swift
//  LowmadKit
//
//  Created by Johan Thorell on 2020-10-31.
//

import Foundation

struct Command: Codable, Equatable {
    let name, source, commit: String
}
