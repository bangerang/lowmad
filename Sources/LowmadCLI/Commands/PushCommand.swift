import Foundation
import SwiftCLI
import LowmadKit

class PushCommand: LowmadCommand {

    @Param var commitMessage: String

    @Param var branch: String?

    @Flag("-p", "--pull-before") var pullBefore: Bool

    init(lowmad: Lowmad) {
        super.init(lowmad: lowmad,
                   name: "push",
                   description: "",
                   longDescription: "")
    }

    override func execute() throws {
        try lowmad.runPush(message: commitMessage, branch: branch, pullBefore: pullBefore)
    }
}
