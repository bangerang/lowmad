import Foundation
import SwiftCLI
import LowmadKit

class LowmadCommand: Command {

    let lowmad: Lowmad
    let name: String
    let shortDescription: String
    let longDescription: String

    init(lowmad: Lowmad, name: String, description: String, longDescription: String = "") {
        self.lowmad = lowmad
        self.name = name
        self.shortDescription = description
        self.longDescription = longDescription
    }

    func execute() throws {}
}
