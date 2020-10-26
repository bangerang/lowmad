//
//  main.swift
//  lowmad
//
//  Created by Johan Thorell on 2020-10-19.
//

import Foundation
import ArgumentParser
import Files
import Rainbow

extension String: Error {}

struct Lowmad: ParsableCommand {

    static let name = "lowmad"

    static let localPath = "/usr/local/lib"

    static func getEnvironment() throws -> Environment {
        let environmentFile = try File(path: "\(Lowmad.localPath)/\(Lowmad.name)/environment.json")
        return try JSONDecoder().decode(Environment.self, from: try environmentFile.read())
    }
    
    struct Init: ParsableCommand {
        private enum CodingKeys: CodingKey {}

        let lldbInit = """
        import lldb
        import os

        def __lldb_init_module(debugger, internal_dict):
            file_path = os.path.realpath(__file__)
            dir_name = os.path.dirname(file_path)
            load_python_scripts_dir(dir_name + '/commands')

        def load_python_scripts_dir(dir_name):
            this_files_basename = os.path.basename(__file__)
            cmd = ''
            for file in os.listdir(dir_name):
                if file.endswith('.py'):
                    cmd = 'command script import '
                elif file.endswith('.txt'):
                    cmd = 'command source -e0 -s1 '
                else:
                    continue

                if file != this_files_basename:
                    fullpath = dir_name + '/' + file
                    lldb.debugger.HandleCommand(cmd + fullpath)
        """

        func run() throws {

            print("? ".green.bold + "Where do you want to store your commands? Leave empty for default directory.".bold + " (\(Lowmad.localPath))".lightBlack)

            func getPath() throws -> Folder? {
                if let path = readLine(), !path.isEmpty {
                    do {
                        let commandsFolder = try Folder(path: path)
                        print("i  \(Lowmad.name): ".cyan.bold + "Installing into \(path)/\(Lowmad.name)/commands...")
                        return commandsFolder
                    } catch {
                        print("✖  \(Lowmad.name): ".red.bold + "Not a valid directory, try again.")
                        return nil
                    }
                } else {
                    print("i  \(Lowmad.name): ".cyan.bold + "Installing into \(Lowmad.localPath)/\(Lowmad.name)/commands...")
                    return try Folder(path: "\(Lowmad.localPath)")
                }
            }

            var rootFolder: Folder? = nil

            repeat {
                rootFolder = try getPath()
            } while rootFolder == nil


            let lowmadFolder = try rootFolder!.createSubfolder(at: "\(Lowmad.name)")

            let commandsFolder = try lowmadFolder.createSubfolder(at: "commands")

            print("i  \(Lowmad.name): ".cyan.bold + "Creating \(Lowmad.name) import file...")
            let lowmadFile = try lowmadFolder.createFile(named: "\(Lowmad.name).py")
            try lowmadFile.write(lldbInit)

            let localFolder = try Folder(path: Lowmad.localPath)

            if !localFolder.containsSubfolder(at: Lowmad.name) {
                try localFolder.createSubfolder(named: Lowmad.name)
            }

            let environmentFile = try localFolder.subfolder(named: Lowmad.name).createFile(named: "environment.json")
            let environment = Environment(commandsPath: commandsFolder.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(environment)
            try environmentFile.write(data)

            let homeFolder = Folder.home

            let importCommand = "command script import \(lowmadFolder.path)\(Lowmad.name).py\n"

            let editLLDBFile: (File) throws -> Void = { file in
                let content = try file.readAsString()
                if !content.contains(importCommand) {
                    print("i  \(Lowmad.name): ".cyan.bold + "Updating global lldbinit file...")
                    try file.append(importCommand)
                }
            }

            if !homeFolder.containsFile(named: ".lldbinit") {
                print("i  \(Lowmad.name): ".cyan.bold + "global lldbinit file does not exist, creating...")
                try homeFolder.createFile(named: ".lldbinit")
            }

            let lldbInitFile = try homeFolder.file(at: ".lldbinit")
            try editLLDBFile(lldbInitFile)
            print("✔  \(Lowmad.name): ".green.bold + "You're all set up! 👍".bold)
        }
    }

    struct Install: ParsableCommand {

        @Argument(help: "URL to Git repo")
        var gitURL: String?

        @Argument(help: "Choose a subset of commands from a Git repo. Needs to formatted with comma and no spaces, e.g: install foo,bar", transform: {
            return $0.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ",")
        })
        var subset: [String]?

        @Option(help: "Install from manifest file, both file path and Git URL is supported")
        var manifestURL: String?

        @Option(help: "Clone from specific commit")
        var commit: String?

        var hasBeenInitialized: Bool {
            do {
                let folder = try Folder(path: "\(Lowmad.localPath)/\(Lowmad.name)/")
                return folder.containsFile(named: "environment.json")
            } catch {
                return false
            }
        }

        func run() throws {

            func cleanup() {
                shell("rm -rf \(Lowmad.localPath)/\(Lowmad.name)/temp")
            }

            defer {
                cleanup()
            }

            if !hasBeenInitialized {
                throw "✖  \(Lowmad.name): ".red.bold + "Has not been initialized, did you forget to run the init command?"
            }

            cleanup()

            if let gitURL = gitURL {
                print("i  \(Lowmad.name): ".cyan.bold + "Cloning \(gitURL)...".bold)
                shell("git clone \(gitURL) \(Lowmad.localPath)/\(Lowmad.name)/temp")
                let commitToUse: String

                if let commit = commit {
                    commitToUse = commit
                    print("i  \(Lowmad.name): ".cyan.bold + "Checking out commit \(commitToUse)")
                    shell("git checkout \(commitToUse)")
                } else {
                    commitToUse = shell("cd \(Lowmad.localPath)/\(Lowmad.name)/temp && git rev-parse HEAD", disableOutput: false).replacingOccurrences(of: "\n", with: "")
                }

                try copyFilesToScriptsFolder(from: try Folder(path: "\(Lowmad.localPath)/\(Lowmad.name)/temp"), subset: subset) { file in
                    try saveToManifestFile(file: file, source: gitURL, commit: commitToUse)
                }
            } else if let manifest = manifestURL {
                let regexString = "((git|ssh|http(s)?)|(git@[\\w\\.]+))(:(//)?)([\\w\\.@\\:/\\-~]+)(\\.git)(/)?"
                let regex = try NSRegularExpression(pattern: regexString)
                let results = regex.matches(in: manifest, range: NSRange(manifest.startIndex..., in: manifest))
                let file: File
                if results.isEmpty {
                    file = try File(path: manifest)
                    guard file.extension == "json" else {
                        throw "✖  \(Lowmad.name): ".red.bold + "manifest file has wrong file extension"
                    }

                } else {
                    shell("cd \(Lowmad.localPath)/\(Lowmad.name)/temp")
                    shell("git clone \(manifest) manifest")
                    file = try File(path: "\(Lowmad.localPath)/\(Lowmad.name)/temp/manifest/manifest.json")
                }

                let manifestStruct = try JSONDecoder().decode(lowmad.Manifest.self, from: try file.read())
                var dict: [String: [String: [String]]] = [:]

                for command in manifestStruct.commands {
                    if dict[command.source] == nil {
                        dict[command.source] = [:]
                    }
                    if dict[command.source]?[command.commit] == nil {
                        dict[command.source]?[command.commit] = []
                    }
                    dict[command.source]?[command.commit]?.append(command.name)
                }

                for (key, value) in dict {
                    let uuid = UUID().uuidString
                    let path = "\(Lowmad.localPath)/\(Lowmad.name)/temp/\(uuid)"
                    print("i  \(Lowmad.name): ".cyan.bold + "Cloning \(key)...".bold)
                    shell("git clone \(key) \(path)")
                    for (commit, subset) in value {
                        shell("cd \(path) && git checkout \(commit)")
                        try copyFilesToScriptsFolder(from: try Folder(path: path), subset: subset) { file in
                           try saveToManifestFile(file: file, source: key, commit: commit)
                        }
                    }
                }
            } else {
                throw "✖  \(Lowmad.name): ".red.bold + "Please supply a git URL or a manifest file."
            }

            print("✔  \(Lowmad.name): ".green.bold + "Installation was successful! 🎉".bold)
        }

        func copyFilesToScriptsFolder(from rootFolder: Folder, subset: [String]? = nil, didCopyFileCompletion: (File) throws -> Void) throws {
            var pythonFiles = [File]()

            func searchFolderForPythonFiles(_ folder: Folder) {
                for file in folder.files {
                    if file.extension == "py" {
                        pythonFiles.append(file)
                    }
                }
            }

            searchFolderForPythonFiles(rootFolder)
            rootFolder.subfolders.recursive.forEach(searchFolderForPythonFiles)

            let validFiles = try pythonFiles.filter {
                let content = try $0.readAsString()
                return content.contains("__lldb_init_module")
            }

            let environment = try Lowmad.getEnvironment()
            let commandsFolder = try Folder(path: environment.commandsPath)

            func copyFile(_ file: File) throws {
                print("i  \(Lowmad.name): ".cyan.bold + "Copying \(file.name) into commands folder...")
                shell("cd \(commandsFolder.path) && rm \(file.name)")

                try file.copy(to: commandsFolder)
                try didCopyFileCompletion(file)
            }

            if let subset = subset {
                let filteredFiles = validFiles.filter {
                    return subset.contains($0.nameExcludingExtension)
                }

                if filteredFiles.isEmpty {
                    throw "✖  \(Lowmad.name): ".red.bold + "Could not find \(subset) in given repo"
                }

                try filteredFiles.forEach {
                    try copyFile($0)
                }
            } else {
                try validFiles.forEach {
                    try copyFile($0)
                }
            }
        }

        func saveToManifestFile(file: File, source: String, commit: String) throws {
            var manifest: lowmad.Manifest
            var manifestFile: File

            let environment = try Lowmad.getEnvironment()
            let commandsFolder = try Folder(path: environment.commandsPath)

            if commandsFolder.containsFile(named: "manifest.json") {
                manifestFile = try commandsFolder.file(named: "manifest.json")
                manifest = try JSONDecoder().decode(lowmad.Manifest.self, from: try manifestFile.read())
            } else {

                manifest = lowmad.Manifest(version: "0.1", commands: [])
                manifestFile = try commandsFolder.createFile(named: "manifest.json")
            }

            let newCommand = Command(name: file.nameExcludingExtension, source: source, commit: commit)

            if let index = manifest.commands.firstIndex(where: { $0.name == newCommand.name && $0.source == newCommand.source }) {
                manifest.commands[index] = newCommand
            } else {
                manifest.commands.append(newCommand)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(manifest)
            try manifestFile.write(data)
        }
    }

    struct List: ParsableCommand {
        func run() throws {
            let environment = try Lowmad.getEnvironment()
            let commandsFolder = try Folder(path: environment.commandsPath)
            if commandsFolder.files.count() == 0 {
                print("i  \(Lowmad.name): ".cyan.bold + "No commands found".bold)
                return
            }
            print("Installed commands at \(commandsFolder.path)".bold)
            for file in commandsFolder.files {
                if file.extension == "py" {
                    print(file.nameExcludingExtension)
                }
            }
        }
    }

    struct Uninstall: ParsableCommand {

        @Argument(help: "Only uninstall a subset of commands from a Git repo. Needs to formatted with comma and no spaces, e.g: uninstall foo,bar", transform: {
            return $0.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ",")
        })
        var subset: [String]?

        func run() throws {
            let environment = try Lowmad.getEnvironment()
            let allCommands = try Folder(path: environment.commandsPath).files
            if let subset = subset {
                let subsetCommands = allCommands.filter {
                    return subset.contains($0.nameExcludingExtension)
                }
                try subsetCommands.forEach{
                    print("i  \(Lowmad.name): ".cyan.bold + "Deleting \($0.name)...")
                    try $0.delete()
                }
            } else {
                try allCommands.forEach{
                    print("i  \(Lowmad.name): ".cyan.bold + "Deleting \($0.name)...")
                    try $0.delete()
                }
            }
            print("✔  \(Lowmad.name): ".green.bold + "Commands were successfully deleted".bold)
        }
    }

    struct Generate: ParsableCommand {

        @Argument(help: "The name for the script to generate")
        var name: String

        @Argument(help: "Select a custom path for this script, if not supplied commands folder will be used.")
        var path: String?

        func run() throws {
            let folder: Folder
            if let path = path {
                folder = try Folder(path: path)
            } else {
                let environment = try Lowmad.getEnvironment()
                folder = try Folder(path: environment.commandsPath)
            }

            if folder.containsFile(named: name) {
                throw "✖  \(Lowmad.name): ".red.bold + "There already exists a file named \(name), please remove the file at \(folder.path) first"
            }
            let file = try folder.createFile(named: "\(name).py")
            try file.write(createScript(name: name))
            print("✔  \(Lowmad.name): ".green.bold + "Script for command \(name) was successfully created".bold)
            shell("open -R \(file.path)")
        }

        func createScript(name: String) -> String {
            return """
            import lldb
            import os
            import shlex
            import optparse

            def __lldb_init_module(debugger, internal_dict):
                debugger.HandleCommand('command script add -f \(name).handle_command \(name) -h "Short documentation here"')

            def handle_command(debugger, command, exe_ctx, result, internal_dict):

                command_args = shlex.split(command, posix=False)
                parser = generate_option_parser()
                try:
                    (options, args) = parser.parse_args(command_args)
                except:
                    result.SetError(parser.usage)
                    return

                # Uncomment if you are expecting at least one argument
                # clean_command = shlex.split(args[0])[0]

                result.AppendMessage('Hello! the \(name) command is working!')


            def generate_option_parser():
                usage = "usage: %prog [options] TODO Description Here :]"
                parser = optparse.OptionParser(usage=usage, prog="\(name)")
                parser.add_option("-m", "--module",
                                  action="store",
                                  default=None,
                                  dest="module",
                                  help="This is a placeholder option to show you how to use options with strings")
                parser.add_option("-c", "--check_if_true",
                                  action="store_true",
                                  default=False,
                                  dest="store_true",
                                  help="This is a placeholder option to show you how to use options with bools")
                return parser
            """
        }
    }

    struct Manifest: ParsableCommand {
        func run() throws {
            let environment = try Lowmad.getEnvironment()
            let commandsFolder = try Folder(path: environment.commandsPath)
            print("\(try commandsFolder.file(named: "manifest.json").path)")
        }
    }

    static var configuration = CommandConfiguration(
        abstract: "A command line tool for managing and generating LLDB scripts.",
        subcommands: [Init.self, Install.self, List.self, Uninstall.self, Generate.self, Manifest.self],
        defaultSubcommand: Install.self)
}

@discardableResult
func shell(_ command: String, disableOutput: Bool = true) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    let c = disableOutput ? command + " &>/dev/null" : command
    task.arguments = ["-c", c]
    task.launchPath = "/bin/bash"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

// MARK: - Manifest
struct Manifest: Codable {
    let version: String
    var commands: [Command]
}

// MARK: - Command
struct Command: Codable, Equatable {
    let name, source, commit: String
}

// MARK: Environment
struct Environment: Codable {
    let commandsPath: String
}

var firstPrint = true
func print(_ items: Any...) {
    if let string = items[0] as? String {
        if firstPrint {
            firstPrint = false
            Swift.print("\n" + string)
        } else {
            Swift.print(string)
        }
    }
}

Lowmad.main()
