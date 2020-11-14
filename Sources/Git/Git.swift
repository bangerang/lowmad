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

    public var addAndCommit: (String) -> Void = { message in
        Shell.runSilentCommand("git commit -am \(message)")
    }

    public var pull: (String, String?) -> Void = { gitURL, branch in
        var branchToPull = branch ?? "master"
        Shell.runSilentCommand("git pull origin \(branchToPull)")
    }

    public var push: (String, String?) -> Void = { gitURL, branch in
        var branchToPush = branch ?? "master"
        Shell.runSilentCommand("git push origin \(branchToPush)")
    }
}
