import Foundation
import SwiftCLI
import LowmadKit

class UninstallCommand: LowmadCommand {

    @Flag("-o", "--own", description: "Only delete scripts from own specified commands folder.") var own: Bool

    @Flag("-f", "--fetched", description: "Only delete fetched scripts.") var fetched: Bool

    @CollectedParam var subset: [String]

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "uninstall",
                   description: "Uninstall scripts.",
                   longDescription: "Uninstall scripts.")
    }

    override func execute() throws {
        try lowmad.hasBeenInitialized {
            try lowmad.runUninstall(subset: subset, own: own, fetched: fetched)
        }
    }
}
