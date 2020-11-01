import Foundation

struct Manifest: Codable {
    let version: String
    var commands: [Command]
}
