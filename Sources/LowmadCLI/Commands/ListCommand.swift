import Foundation
import SwiftCLI
import LowmadKit

class ListCommand: LowmadCommand {

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "list",
                   description: "",
                   longDescription: "")
    }

    override func execute() throws {
        try lowmad.runList()
    }
}
