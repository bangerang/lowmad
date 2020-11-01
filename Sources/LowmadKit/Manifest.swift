//
//  Manifest.swift
//  LowmadKit
//
//  Created by Johan Thorell on 2020-10-31.
//

import Foundation

struct Manifest: Codable {
    let version: String
    var commands: [Command]
}
