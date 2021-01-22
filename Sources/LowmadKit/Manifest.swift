import Foundation

struct ManifestV1: Codable {
    var commands: [Command]
}
struct ManifestV2: Codable {
    var identifier = Lowmad.name
    var commands: [Command]
    var lldbInit: [String]
}
