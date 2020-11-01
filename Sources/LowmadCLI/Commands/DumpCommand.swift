import Foundation
import SwiftCLI
import LowmadKit

class DumpCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "dump",
                   description: "",
                   longDescription: "")
    }

    override func execute() throws {
        try lowmad.runDump()
    }
}
