import Foundation
import SwiftCLI
import Rainbow
import Files
import World
import Shell

extension String: Error {}

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
}

public class Lowmad {

    static let name = "lowmad"

    var hasBeenInitialized: Bool {
        do {
            let folder = try Current.localFolder().subfolder(at: Lowmad.name)
            return folder.containsFile(named: "environment.json")
        } catch {
            return false
        }
    }

    var lowmadTempFolder = {
        return try Current.localFolder().createSubfolderIfNeeded(at: "\(Lowmad.name)/temp")
    }

    var getEnvironmentFile: () throws -> File = {
        let localFolder = try Current.localFolder()
        return try localFolder.file(at: "/\(Lowmad.name)/environment.json")
    }

    var getEnvironment: () throws -> Environment = {
        let localFolder = try Current.localFolder()
        let environmentFile = try localFolder.file(at: "/\(Lowmad.name)/environment.json")
        return try JSONDecoder().decode(Environment.self, from: try environmentFile.read())
    }

    public init() {

    }
    
    public func runInit() throws {
        let lldbInitScript = """
        import lldb
        import os
        import json

        def __lldb_init_module(debugger, internal_dict):
            file_path = os.path.realpath(__file__)
            dir_name = os.path.dirname(file_path)
            load_python_scripts_dir(dir_name)
            with open('/usr/local/lib/lowmad/environment.json') as json_file:
                data = json.load(json_file)
                commandsPath = os.path.realpath(data['ownCommandsPath'])
                if not dir_name in commandsPath:
                    load_python_scripts_dir(commandsPath)

        def load_python_scripts_dir(dir_name):
            this_files_basename = os.path.basename(__file__)
            cmd = ''
            for r, d, f in os.walk(dir_name):
                for file in f:
                    if '.py' in file:
                        cmd = 'command script import '
                    else:
                        continue
                    if file != this_files_basename:
                        fullpath = os.path.join(r, file)
                        lldb.debugger.HandleCommand(cmd + fullpath)
        """

        let localFolder = try Current.localFolder()

        let prompt = "? ".green.bold + "Where do you want to store your generated commands? Leave empty for default directory.".bold + " (\(localFolder.path)/lowmad/own_commands)".lightBlack

        let installationPath = Current.readLine(prompt, false, [.custom("Not a valid directory, try again.", { (input) -> Bool in
                do {
                    _ = try Folder(path: input)
                    return true
                } catch {
                    return false
                }
            })],
            { (input, reason) in
                Term.stderr <<< "'\(input)' is not a valid directory, try again."
            }
        )

        let lowmadFolder = try localFolder.createSubfolder(at: "\(Lowmad.name)")

        _ = try lowmadFolder.createSubfolder(at: "commands")

        let ownCommandsFolder: Folder

        if installationPath.isEmpty {
            ownCommandsFolder = try lowmadFolder.createSubfolder(at: "own_commands")
        } else {
            ownCommandsFolder = try Folder(path: installationPath).createSubfolder(at: "/\(Lowmad.name)")
        }

        print("i  \(Lowmad.name): ".cyan.bold + "Creating \(Lowmad.name) import file...")
        let lowmadFile = try lowmadFolder.createFile(named: "\(Lowmad.name).py")
        try lowmadFile.write(lldbInitScript)

        if !localFolder.containsSubfolder(at: Lowmad.name) {
            try localFolder.createSubfolder(named: Lowmad.name)
        }

        let environmentFile = try localFolder.subfolder(named: Lowmad.name).createFile(named: "environment.json")
        let environment = Environment(ownCommandsPath: ownCommandsFolder.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(environment)
        try environmentFile.write(data)

        let homeFolder = Current.homeFolder()

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

    private func createSubfolderNameFromGitURL(_ gitURL: String) throws -> String {
        let regexPattern = "^(https|git)(://|@)([^/:]+)[/:]([^/:]+)/(.+).git$"
        let groups = try gitURL.regexGroups(for: regexPattern)
        guard var strings = groups.first else {
            throw "Could not parse Git URL"
        }
        guard let repoName = strings.popLast() else {
            throw "Could not parse Git URL"
        }
        guard let author = strings.popLast() else {
            throw "Could not parse Git URL"
        }
        return "\(author)-\(repoName)"
    }

    public func runInstall(gitURL: String?, subset: [String], manifestURL: String?, commit: String?, ownRepo: Bool) throws {

        func cleanup() {
            do {
                let tempFolder = try Current.localFolder().subfolder(at: "\(Lowmad.name)/temp")
                Shell.runSilentCommand("rm -rf \(tempFolder.path)")
            } catch {

            }
        }

        defer {
            cleanup()
        }

        if !hasBeenInitialized {
            throw "✖  \(Lowmad.name): ".red.bold + "Has not been initialized, did you forget to run the init command?"
        }

        cleanup()

        let tempFolder = try lowmadTempFolder()

        let commandsFolder: Folder
        if ownRepo {
            commandsFolder = try getOwnCommandsFolder()
        } else {
            commandsFolder = try getLowmadCommandsFolder()
        }
        
        if let gitURL = gitURL {
            guard try isGitURL(gitURL) else {
                throw "Not a valid Git URL"
            }
            print("i  \(Lowmad.name): ".cyan.bold + "Cloning \(gitURL)...".bold)

            Current.git.clone(gitURL, tempFolder.path)

            let commitToUse: String

            if let commit = commit {
                commitToUse = commit
                print("i  \(Lowmad.name): ".cyan.bold + "Checking out commit \(commitToUse)")
                Shell.runSilentCommand("git checkout \(commitToUse)")
            } else {
                commitToUse = try Current.git.getCommit(tempFolder.path)
            }

            let destinationFolder: Folder

            if ownRepo {
                destinationFolder = commandsFolder
            } else {
                destinationFolder = try commandsFolder.createSubfolderIfNeeded(withName: createSubfolderNameFromGitURL(gitURL))
            }


            try copyFilesToScriptsFolder(from: tempFolder, to: destinationFolder, subset: subset) { file in
                try saveToManifestFile(inFolder: commandsFolder, fileToSave: file, source: gitURL, commit: commitToUse)
            }
        } else if let manifest = manifestURL {
            let isGit = try isGitURL(manifest)
            let file: File
            if isGit {
                Shell.runSilentCommand("cd \(tempFolder.path)")
                Current.git.clone(manifest, "manifest")
                file = try tempFolder.file(at: "/manifest/manifest.json")
            } else {
                file = try File(path: manifest)
                guard file.extension == "json" else {
                    throw "✖  \(Lowmad.name): ".red.bold + "manifest file has wrong file extension"
                }
            }

            let manifestStruct = try JSONDecoder().decode(Manifest.self, from: try file.read())
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

                let path = try tempFolder.createSubfolderIfNeeded(at: uuid).path
                print("i  \(Lowmad.name): ".cyan.bold + "Cloning \(key)...".bold)
                Current.git.clone(key, path)

                for (commit, subset) in value {
                    Shell.runSilentCommand("cd \(path) && git checkout \(commit)")

                    let destinationFolder: Folder

                    if ownRepo {
                        destinationFolder = commandsFolder
                    } else {
                        destinationFolder = try commandsFolder.createSubfolderIfNeeded(withName: createSubfolderNameFromGitURL(key))
                    }

                    try copyFilesToScriptsFolder(from: try Folder(path: path), to: destinationFolder, subset: subset) { file in
                        try saveToManifestFile(inFolder: commandsFolder, fileToSave: file, source: key, commit: commit)
                    }
                }
            }
        } else {
            throw "✖  \(Lowmad.name): ".red.bold + "Please supply a git URL or a manifest file."
        }

        print("✔  \(Lowmad.name): ".green.bold + "Installation was successful! 🎉".bold)
    }

    private func getLowmadCommandsFolder() throws -> Folder {
        let localFolder = try Current.localFolder()
        return try localFolder.subfolder(at: "\(Lowmad.name)/commands")
    }

    private func getOwnCommandsFolder() throws -> Folder {
        return try Folder(path: getEnvironment().ownCommandsPath)
    }

    private func isGitURL(_ string: String) throws -> Bool {
        let regexString = "((git|ssh|http(s)?)|(git@[\\w\\.]+))(:(//)?)([\\w\\.@\\:/\\-~]+)(\\.git)(/)?"
        let regex = try NSRegularExpression(pattern: regexString)
        let results = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        return results.count > 0
    }

    private func copyFilesToScriptsFolder(from source: Folder, to destination: Folder, subset: [String]? = nil, didCopyFileCompletion: (File) throws -> Void) throws {
        var pythonFiles = [File]()

        func searchFolderForPythonFiles(_ folder: Folder) {
            for file in folder.files {
                if file.extension == "py" {
                    pythonFiles.append(file)
                }
            }
        }

        searchFolderForPythonFiles(source)
        source.subfolders.recursive.forEach(searchFolderForPythonFiles)

        let validFiles = try pythonFiles.filter {
            let content = try $0.readAsString()
            return content.contains("__lldb_init_module")
        }

        func copyFile(_ file: File) throws {
            print("i  \(Lowmad.name): ".cyan.bold + "Copying \(file.name) into commands folder...")
            if destination.containsFile(named: file.name) {
                print("⚠  \(Lowmad.name): ".yellow.bold + "Will not copy \(file.name.bold) into \(destination.path), file already exists.")
                return
            }
            try file.copy(to: destination)
            try didCopyFileCompletion(file)
        }

        if let subset = subset, !subset.isEmpty {
            let filteredFiles = validFiles.filter {
                return subset.contains($0.name) || subset.contains($0.nameExcludingExtension)
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

    private func writeEnvironmentToFile(_ environment: Environment) throws {
        let environmentFile = try getEnvironmentFile()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(environment)
        try environmentFile.write(data)
    }

    private func saveToManifestFile(inFolder commandsFolder: Folder, fileToSave: File, source: String, commit: String) throws {
        var manifest: Manifest
        var manifestFile: File

        if commandsFolder.containsFile(named: "manifest.json") {
            manifestFile = try commandsFolder.file(named: "manifest.json")
            manifest = try JSONDecoder().decode(Manifest.self, from: try manifestFile.read())
        } else {

            manifest = Manifest(version: "0.1", commands: [])
            manifestFile = try commandsFolder.createFile(named: "manifest.json")
        }

        let newCommand = Command(name: fileToSave.nameExcludingExtension, source: source, commit: commit)

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

    public func runList() throws {
        let environment = try getEnvironment()
        let ownCommandsFolder = try Folder(path: environment.ownCommandsPath)
//         source.subfolders.recursive.forEach(searchFolderForPythonFiles)
        let commandsFolder = try Current.lowmadFolder().subfolder(named: "commands")
        if ownCommandsFolder.files.count() == 0 {
            print("i  \(Lowmad.name): ".cyan.bold + "No commands found".bold)
            return
        }
        print("Installed commands at \(ownCommandsFolder.path)".bold)
        for file in ownCommandsFolder.files {
            if file.extension == "py" {
                print(file.nameExcludingExtension)
            }
        }
        print("Installed commands at \(commandsFolder.path)".bold)
        for folder in commandsFolder.subfolders.recursive {
            for file in folder.files {
                if file.extension == "py" {
                    print(file.nameExcludingExtension)
                }
            }
        }
    }

    private func deleteFiles(_ files: Folder.ChildSequence<File>, subset: [String]) throws {
        func deleteFile(_ file: File) throws {
            let content = try file.readAsString()
            if content.contains("__lldb_init_module") {
                print("i  \(Lowmad.name): ".cyan.bold + "Deleting \(file.name)...")
                try file.delete()
            }
        }
        if !subset.isEmpty {
            let subsetCommands = files.filter {
                return subset.contains($0.nameExcludingExtension)
            }
            try subsetCommands.forEach{
                try deleteFile($0)
            }
        } else {
            try files.forEach{
                try deleteFile($0)
            }
        }
    }

    public func runUninstall(subset: [String], own: Bool, fetched: Bool) throws {
        let allCommands: Folder.ChildSequence<File>
        if own {
            let environment = try getEnvironment()
            allCommands = try Folder(path: environment.ownCommandsPath).files
            try deleteFiles(allCommands, subset: subset)
        } else if fetched {
            allCommands = try Current.lowmadFolder().subfolder(named: "commands").files
            try deleteFiles(allCommands, subset: subset)
        } else {
            let environment = try getEnvironment()
            let ownCommands = try Folder(path: environment.ownCommandsPath).files
            let fetchedCommands = try Current.lowmadFolder().subfolder(named: "commands").files
            try deleteFiles(ownCommands, subset: subset)
            try deleteFiles(fetchedCommands, subset: subset)
        }
        print("✔  \(Lowmad.name): ".green.bold + "Commands were successfully deleted".bold)
    }

    public func runGenerate(name: String, path: String?) throws {
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
        
        let folder: Folder
        if let path = path {
            folder = try Folder(path: path)
        } else {
            let environment = try getEnvironment()
            folder = try Folder(path: environment.ownCommandsPath)
        }

        if folder.containsFile(named: name) {
            throw "✖  \(Lowmad.name): ".red.bold + "There already exists a file named \(name), please remove the file at \(folder.path) first"
        }
        let file = try folder.createFile(named: "\(name).py")
        try file.write(createScript(name: name))
        print("✔  \(Lowmad.name): ".green.bold + "Script for command \(name) was successfully created".bold)
        Shell.runSilentCommand("open -R \(file.path)")
    }

    public func runDump() throws {
        let environment = try getEnvironment()
        let commandsFolder = try Folder(path: environment.ownCommandsPath)
        let file = try commandsFolder.file(named: "manifest.json")
        print("\(file.path)".bold)
        print(try file.readAsString())
    }

}
