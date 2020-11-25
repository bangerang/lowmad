import Foundation
import SwiftCLI
import LowmadKit

class InitCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "init",
                   description: "Initialize lowmad.",
                   longDescription: "Initialize lowmad.")
    }

    override func execute() throws {
        try lowmad.runInit()
    }
}


