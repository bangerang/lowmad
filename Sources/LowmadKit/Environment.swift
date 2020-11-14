import Foundation


struct Environment: Codable {
    let ownCommandsPath: String
    var source: Source?
}
struct Source: Codable {
    let url: String
    let lastRevision: String
}
