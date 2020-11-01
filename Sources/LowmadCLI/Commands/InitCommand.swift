//
//  InitCommand.swift
//  LowmadCLI
//
//  Created by Johan Thorell on 2020-10-31.
//

import Foundation
import SwiftCLI
import LowmadKit

class InitCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "init",
                   description: "",
                   longDescription: "")
    }

    override func execute() throws {
        try lowmad.runInit()
    }
}


