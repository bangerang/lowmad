import Foundation
import SwiftCLI
import LowmadKit

class DumpCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "dump",
                   description: "Dumps path and content of manifest file.",
                   longDescription: "Dumps path and content of manifest file.")
    }

    override func execute() throws {
        try lowmad.runMigration()
        try lowmad.hasBeenInitialized()
        try lowmad.runDump()
    }
}
