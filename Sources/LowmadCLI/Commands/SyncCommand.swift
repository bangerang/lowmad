//
//  SyncCommand.swift
//  LowmadCLI
//
//  Created by Johan Thorell on 2021-01-21.
//

import Foundation
import SwiftCLI
import LowmadKit

class SyncCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "sync",
                   description: "Sync contents of LLDB init to manifest",
                   longDescription: "Sync contents of LLDB init to manifest")
    }

    override func execute() throws {
        try lowmad.runMigration()
        try lowmad.hasBeenInitialized()
        try lowmad.runSync()
    }
}
