import Foundation
import SwiftCLI

public struct Shell {

    static public var runSilentCommand: (String) -> Void = { command in
        let task = Task(executable: "/bin/bash", arguments: ["-c", command])
        _ = task.runSync()
    }

    static public var runCommand: (String) throws -> Void = { command in
        try Task.run(bash: command)
    }

    static public var capture: (String) throws -> CaptureResult = { command in
        return try Task.capture(bash: command)
    }
}
