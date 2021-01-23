//
//  Extensions.swift
//  LowmadCLI
//
//  Created by Johan Thorell on 2021-01-23.
//

import Foundation
import Files

extension String {
    func regexGroups(for regexPattern: String) throws -> [[String]] {
        let text = self
        let regex = try NSRegularExpression(pattern: regexPattern)
        let matches = regex.matches(in: text,
                                    range: NSRange(text.startIndex..., in: text))
        return matches.map { match in
            return (0..<match.numberOfRanges).map {
                let rangeBounds = match.range(at: $0)
                guard let range = Range(rangeBounds, in: text) else {
                    return ""
                }
                return String(text[range])
            }
        }
    }

    static func error(_ text: String) -> String {
        return "✖  \(Lowmad.name): ".red.bold + text
    }

    static func info(_ text: String) -> String {
        return "i  \(Lowmad.name): ".cyan.bold + text
    }

    static func warning(_ text: String) -> String {
        return "⚠  \(Lowmad.name): ".yellow.bold + text
    }

    static func done(_ text: String) -> String {
        return "✔  \(Lowmad.name): ".green.bold + text.bold
    }
}

extension File {
    func isLLDBScript() throws -> Bool {
        let content = try readAsString()
        return content.contains("__lldb_init_module") || content.contains("@lldb.command")
    }
}
