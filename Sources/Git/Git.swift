//
//  Git.swift
//  lowmad
//
//  Created by Johan Thorell on 2020-10-31.
//

import Foundation
import Shell

public struct Git {
    public init() {}

    public var clone: (String, String?) -> Void = { gitURL, location in
        var command = "git clone \(gitURL)"
        if let location = location {
            command += " \(location)"
        }
        Shell.runSilentCommand(command)
    }

    public var checkout: (String) -> Void = { location in
        Shell.runSilentCommand("git checkout \(location)")
    }

    public var getCommit: (String) throws -> String = { location in
        let result = try Shell.capture("cd \(location) && git rev-parse HEAD")
        return result.stdout.replacingOccurrences(of: "\n", with: "")
    }
}
