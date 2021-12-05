import Foundation
import SwiftCLI
import LowmadKit

class ListCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "list",
                   description: "List all available LLDB commands.",
                   longDescription: "List all available LLDB commands.")
    }

    override func execute() throws {
        try lowmad.runMigration()
        try lowmad.hasBeenInitialized()
        try lowmad.runList()
    }
}
