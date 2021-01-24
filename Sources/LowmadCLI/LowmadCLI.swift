import Foundation
import Rainbow
import SwiftCLI
import LowmadKit

public class LowmadCLI {

    public let version = "0.4.0"

    let cli: CLI

    let lowmad = Lowmad()

    public init() {
        cli = CLI(name: "lowmad", version: version, description: "A command line tool for managing and generating LLDB scripts.", commands: [
            InitCommand(lowmad: lowmad),
            InstallCommand(lowmad: lowmad),
            ListCommand(lowmad: lowmad),
            UninstallCommand(lowmad: lowmad),
            GenerateCommand(lowmad: lowmad),
            DumpCommand(lowmad: lowmad),
            SyncCommand(lowmad: lowmad)
        ])
        cli.parser.parseOptionsAfterCollectedParameter = true
    }

    public func execute(arguments: [String]? = nil) {
        let status: Int32
        if let arguments = arguments {
            status = cli.go(with: arguments)
        } else {
            status = cli.go()
        }
        exit(status)
    }
}

