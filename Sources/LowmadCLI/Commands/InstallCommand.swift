import Foundation
import SwiftCLI
import LowmadKit

class InstallCommand: LowmadCommand {

    @Param var gitURL: String

    @Key("-c", "--commit", description: "Install from a specific commit.") var commit: String?

    @Flag("-o", "--own", description: "Install commands to your own specified commands folder.") var ownRepo: Bool

    @CollectedParam(minCount: 0) var subset: [String]

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "install",
                   description: "Install scripts and configuration from a repo.",
                   longDescription: "Install scripts and configuration from a repo.")
    }

    override func execute() throws {
        try lowmad.runMigration()
        try lowmad.hasBeenInitialized()
        try lowmad.runInstall(gitURL: gitURL, subset: subset, commit: commit, ownRepo: ownRepo)
    }
}


