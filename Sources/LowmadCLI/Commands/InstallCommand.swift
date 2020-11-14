import Foundation
import SwiftCLI
import LowmadKit

class InstallCommand: LowmadCommand {

    @Param var gitURL: String?
    
    @Key("-m", "--manifest", description: "") var manifestURL: String?

    @Key("-c", "--commit", description: "") var commit: String?

    @Flag("-o", "--own") var ownRepo: Bool

    @CollectedParam(minCount: 0) var subset: [String]

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "install",
                   description: "",
                   longDescription: "")
    }

    override func execute() throws {
        try lowmad.runInstall(gitURL: gitURL, subset: subset, manifestURL: manifestURL, commit: commit, ownRepo: ownRepo)
    }
}


