import Foundation
import SwiftCLI
import LowmadKit

class GenerateCommand: LowmadCommand {

    @Param var commandName: String

    @Param var path: String?

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "generate",
                   description: "Generates a new LLDB script.",
                   longDescription: "Generates a new LLDB script.")
    }

    override func execute() throws {
        try lowmad.runGenerate(name: commandName, path: path)
    }
}
