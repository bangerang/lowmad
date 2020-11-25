import Foundation
import SwiftCLI
import LowmadKit


extension String {
    var descriptionStyle: String {
        return self.magenta
    }
    var nameStyle: String {
        return self.bold
    }
}

class DumpCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "dump",
                   description: "Dumps path and content of manifest file.",
                   longDescription: "Dumps path and content of manifest file.")
    }

    override func execute() throws {
        try lowmad.runDump()
    }
}
