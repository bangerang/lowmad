import Foundation

struct Command: Codable, Equatable {
    let name, source, commit: String
}
