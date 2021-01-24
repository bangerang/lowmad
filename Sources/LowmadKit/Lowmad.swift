import Foundation
import SwiftCLI
import Rainbow
import Files
import World
import Shell

public class Lowmad {

    static let name = "lowmad"

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

    public func hasBeenInitialized(completion: () throws -> Void) throws {
        do {
            let folder = try Current.localFolder().subfolder(at: Lowmad.name)
            if folder.containsFile(named: "lowmad.py") {
                try completion()
            } else {
                throw CLI.Error(message: String.error("Has not been initialized, did you forget to run the init command?"))
            }
        } catch {
            throw CLI.Error(message: String.error("Has not been initialized, did you forget to run the init command?"))
        }
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
            try:
                with open('/usr/local/lib/lowmad/environment.json') as json_file:
                    data = json.load(json_file)
                    commandsPath = os.path.realpath(data['ownCommandsPath'])
                    if not dir_name in commandsPath:
                        load_python_scripts_dir(commandsPath)
            except IOError:
                print("environment.json not accessible")

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

        let lowmadFolder = try localFolder.createSubfolder(at: "\(Lowmad.name)")

        _ = try lowmadFolder.createSubfolder(at: "commands")

        Print.info("Creating \(Lowmad.name) import file...")

        let lowmadFile = try lowmadFolder.createFile(named: "\(Lowmad.name).py")
        try lowmadFile.write(lldbInitScript)

        if !localFolder.containsSubfolder(at: Lowmad.name) {
            try localFolder.createSubfolder(named: Lowmad.name)
        }

        let homeFolder = Current.homeFolder()

        let importCommand = "command script import \(lowmadFolder.path)\(Lowmad.name).py\n"

        let editLLDBFile: (File) throws -> Void = { file in
            let content = try file.readAsString()
            if !content.contains(importCommand) {
                Print.info("Updating global lldbinit file...")
                try file.append(importCommand)
            }
        }

        if !homeFolder.containsFile(named: ".lldbinit") {
            Print.info("Global lldbinit file does not exist, creating...")
            try homeFolder.createFile(named: ".lldbinit")
        }

        let lldbInitFile = try homeFolder.file(at: ".lldbinit")
        try editLLDBFile(lldbInitFile)
        Print.done("You're all set up! 👍")
    }

    public func runInstall(gitURL: String, subset: [String], commit: String?, ownRepo: Bool) throws {

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

        let localFolder = try Current.localFolder()

        if try !localFolder.subfolder(named: Lowmad.name).containsFile(named: "environment.json") {
            try createEnvironmentFile()
        }

        cleanup()

        let tempFolder = try lowmadTempFolder()

        let ownFolder = try getOwnCommandsFolder()
        let lowmadCommandsFolder = try getLowmadCommandsFolder()

        let commandFolders = [ownFolder, lowmadCommandsFolder]

        let commandsFolder: Folder
        if ownRepo {
            commandsFolder = ownFolder
        } else {
            commandsFolder = lowmadCommandsFolder
        }

        var atLeastOneScriptWasInstalled = false

        guard try isGitURL(gitURL) else {
            throw CLI.Error(message: String.error("Not a valid Git URL"))
        }
        Print.info("Cloning \(gitURL)...".bold)

        Current.git.clone(gitURL, tempFolder.path)

        let commitToUse: String

        if let commit = commit {
            commitToUse = commit
            Print.info("Checking out commit \(commitToUse)")
            Shell.runSilentCommand("cd \(tempFolder.path) && git checkout \(commitToUse)")
        } else {
            commitToUse = try Current.git.getCommit(tempFolder.path)
        }

        var destinationFolder: Folder

        if ownRepo {
            destinationFolder = commandsFolder
        } else {
            destinationFolder = try commandsFolder.createSubfolderIfNeeded(withName: createSubfolderNameFromGitURL(gitURL))
        }

        if let manifestFile = try findManifestFile(in: tempFolder) {
            (atLeastOneScriptWasInstalled, destinationFolder) = try installFromManifest(file: manifestFile, into: destinationFolder, own: ownRepo, gitURL: gitURL)
        }

        var replaceOptionState = ReplaceOptionState(replaceAll: false, replaceNone: false)

        try copyFilesToScriptsFolder(from: tempFolder, to: destinationFolder, subset: subset, replaceOptionState: &replaceOptionState) { file in
            atLeastOneScriptWasInstalled = true
            try commandFolders.forEach {
                try saveToManifestFile(inFolder: $0, fileToSave: file, source: gitURL, commit: commitToUse)
            }
        }

        if atLeastOneScriptWasInstalled {
            Print.done("Installation was successful! 🎉")
        } else {
            Print.warning("No scripts were installed.".bold)
        }
    }

    public func runList() throws {
        let environment = try getEnvironment()
        let ownCommandsFolder = try Folder(path: environment.ownCommandsPath)
        let commandsFolder = try Current.lowmadFolder().subfolder(named: "commands")
        if ownCommandsFolder.files.count() == 0 {
            Print.info("No commands found".bold)
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

    public func runGenerate(name: String, path: String?) throws {
        func createScript(name: String) -> String {
            return """
                     import lldb
                     import os
                     import shlex
                     import optparse

                     @lldb.command("\(name)")
                     def handle_\(name)_command(debugger, expression, ctx, result, internal_dict):

                         command_args = shlex.split(expression, posix=False)
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

        let localFolder = try Current.localFolder()

        if try !localFolder.subfolder(named: Lowmad.name).containsFile(named: "environment.json") {
            try createEnvironmentFile()
        }

        let folder: Folder
        if let path = path {
            folder = try Folder(path: path)
        } else {
            let environment = try getEnvironment()
            folder = try Folder(path: environment.ownCommandsPath)
        }

        if folder.containsFile(named: name) {
            throw CLI.Error(message: String.error("There already exists a file named \(name), please remove the file at \(folder.path) first"))
        }
        let file = try folder.createFile(named: "\(name).py")
        try file.write(createScript(name: name))
        Print.done("Script for command \(name) was successfully created")
        Shell.runSilentCommand("open -R \(file.path)")
    }

    public func runDump() throws {
        let commandsFolder = try getLowmadCommandsFolder()
        if commandsFolder.containsFile(at: "manifest.json") {
            let file = try commandsFolder.file(named: "manifest.json")
            print("\(file.path)".bold)
            print(try file.readAsString())
        } else {
            Print.info("Manifest file doesnt exist, install some scripts!")
        }

    }

    public func runUninstall(subset: [String], own: Bool, fetched: Bool) throws {
        let folder: Folder
        let didDelete: Bool
        if own {
            let environment = try getEnvironment()
            folder = try Folder(path: environment.ownCommandsPath)
            didDelete = try deleteFiles(in: folder, subset: subset, own: true)
        } else if fetched {
            folder = try Current.lowmadFolder().subfolder(named: "commands")
            didDelete = try deleteFiles(in: folder, subset: subset, own: false)
        } else {
            let environment = try getEnvironment()
            let ownCommands = try Folder(path: environment.ownCommandsPath)
            let fetchedCommands = try Current.lowmadFolder().subfolder(named: "commands")
            let didDeleteOwn = try deleteFiles(in: ownCommands, subset: subset, own: true)
            let didDeleteFetched = try deleteFiles(in: fetchedCommands, subset: subset, own: false)
            didDelete = [didDeleteOwn, didDeleteFetched].contains{ $0 == true }
        }

        try deleteCommandsFromManifest(subset: subset)

        if didDelete {
            Print.done("Commands were successfully deleted")
        } else {
            Print.warning("No files were deleted.".bold)
        }
    }

    public func runSync() throws {
        let lldbInitFile = try Current.homeFolder().file(at: ".lldbinit")

        let commandFolders = try getCommandFolders()

        let lines = try lldbInitFile.readAsString().components(separatedBy: "\n").filter { !$0.isEmpty }

        try commandFolders.forEach {
            let file = try createManifestFileIfNeeded(in: $0)
            var manifest = try getManifest(from: file)
            manifest.lldbInit = lines
            try writeToManifestFile(manifest: manifest, file: file)
        }
    }

    private func deleteCommandsFromManifest(subset: [String]) throws {
        let folders = try getCommandFolders()

        for folder in folders {
            if let manifestFile = try findManifestFile(in: folder) {
                var manifest = try getManifest(from: manifestFile)
                if subset.isEmpty {
                    manifest.commands = []
                    try writeToManifestFile(manifest: manifest, file: manifestFile)
                } else {
                    let commands = Set(manifest.commands.map{ $0.name })
                    let result = commands.subtracting(subset)
                    manifest.commands = manifest.commands.filter { result.contains($0.name) }
                    try writeToManifestFile(manifest: manifest, file: manifestFile)
                }
            }
        }

    }

    private func getCommandFolders() throws -> [Folder] {
        var folders = [try getLowmadCommandsFolder()]
        if let ownFolder = try? getOwnCommandsFolder() {
            folders.append(ownFolder)
        }
        return folders
    }

    private func findManifestFile(in folder: Folder) throws -> File? {
        for file in folder.files {
            if file.name == "manifest.json" {
                let fileAsString = try file.readAsString()
                if fileAsString.contains("\"identifier\" : \"lowmad\"") {
                    return file
                }
            }
        }
        for folder in folder.subfolders.recursive {
            return try findManifestFile(in: folder)
        }

        return nil
    }

    private func folderContainsPythonFiles(_ folder: Folder) -> Bool {
        for file in folder.files {
            if file.extension == "py" {
                return true
            }
        }
        for subfolder in folder.subfolders.recursive {
            return folderContainsPythonFiles(subfolder)
        }

        return false
    }

    private func installScriptsFromManifest(file: File, into folder: Folder, own: Bool) throws -> Bool {

        let uuid = UUID().uuidString

        defer {
            try? lowmadTempFolder().subfolder(named: uuid).delete()
        }

        let manifestStruct = try getManifest(from: file)

        var dict: [String: [String: [String]]] = [:]

        let tempFolder = try lowmadTempFolder().createSubfolder(named: uuid)

        for command in manifestStruct.commands {
            if dict[command.source] == nil {
                dict[command.source] = [:]
            }
            if dict[command.source]?[command.commit] == nil {
                dict[command.source]?[command.commit] = []
            }
            dict[command.source]?[command.commit]?.append(command.name)
        }

        var didInstall = false

        let commandFolders = try getCommandFolders()

        var replaceOptionState = ReplaceOptionState(replaceAll: false, replaceNone: false)

        for (key, value) in dict {
            let uuid = UUID().uuidString

            let path = try tempFolder.createSubfolderIfNeeded(at: uuid).path
            Print.info("Cloning \(key)...".bold)
            Current.git.clone(key, path)

            for (commit, subset) in value {
                Shell.runSilentCommand("cd \(path) && git checkout \(commit)")

                let destinationFolder: Folder = try {
                    if own {
                        return folder
                    } else {
                        return try folder.createSubfolderIfNeeded(withName: createSubfolderNameFromGitURL(key))
                    }
                }()

                try copyFilesToScriptsFolder(from: try Folder(path: path), to: destinationFolder, subset: subset, replaceOptionState: &replaceOptionState) { file in
                    didInstall = true
                    try commandFolders.forEach {
                        try saveToManifestFile(inFolder: $0, fileToSave: file, source: key, commit: commit)
                    }

                }
            }
        }

        return didInstall
    }

    private func installFromManifest(file: File, into folder: Folder, own: Bool, gitURL: String) throws -> (didInstall: Bool, destinationFolder: Folder) {

        let manifest = try getManifest(from: file)

        if manifest.lldbInit.count > 0 {
            let prompt = "? ".green.bold + "Overwrite lldbinit with contents found in manifest?".bold + BinaryOption.description

            let installInit = Reader<BinaryOption>.readLine(prompt: prompt)

            if installInit == .yes {
                let decodoer = JSONDecoder()
                let test = try decodoer.decode(ManifestV2.self, from: try file.read())
                let initString = test.lldbInit.joined(separator: "\n")
                let lldbInitFile = try Current.homeFolder().file(at: ".lldbinit")
                try lldbInitFile.write(initString)
            }
        }

        let prompt = "? ".green.bold + "Install scripts found in manifest?".bold  + BinaryOption.description

        let installManifest = Reader<BinaryOption>.readLine(prompt: prompt)

        var didInstall = false

        if installManifest == .yes {
            didInstall = try installScriptsFromManifest(file: file, into: folder, own: own)
        }

        let tempFolder = try lowmadTempFolder()

        let containsPythonFiles = folderContainsPythonFiles(tempFolder)

        if containsPythonFiles {
            let prompt = "? ".green.bold + "Repo contains additional scripts, do you want to install them?".bold + BinaryOption.description

            let installScripts = Reader<BinaryOption>.readLine(prompt: prompt)

            if installScripts == .yes {
                let prompt = "? ".green.bold + "Do you want to store the commands in your own specified commands folder?".bold + BinaryOption.description

                let own = Reader<BinaryOption>.readLine(prompt: prompt)

                let destinationFolder: Folder = try {
                    if own == .yes {
                        return folder
                    } else {
                        return try folder.createSubfolderIfNeeded(withName: createSubfolderNameFromGitURL(gitURL))
                    }
                }()

                return (didInstall, destinationFolder)
            }
        }

        return (didInstall, folder)
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

    private func createSubfolderNameFromGitURL(_ gitURL: String) throws -> String {
        let regexPattern = "^(https|git)(://|@)([^/:]+)[/:]([^/:]+)/(.+).git$"
        let groups = try gitURL.regexGroups(for: regexPattern)
        guard var strings = groups.first else {
            throw CLI.Error(message: String.error("Could not parse Git URL"))
        }
        guard let repoName = strings.popLast() else {
            throw CLI.Error(message: String.error("Could not parse Git URL"))
        }
        guard let author = strings.popLast() else {
            throw CLI.Error(message: String.error("Could not parse Git URL"))
        }
        return "\(author)-\(repoName)"
    }

    private func copyFilesToScriptsFolder(from source: Folder, to destination: Folder, subset: [String]? = nil, replaceOptionState: inout ReplaceOptionState, didCopyFileCompletion: (File) throws -> Void) throws {
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

        let validFiles = try pythonFiles.filter { try $0.isLLDBScript() }

        func copyFile(_ file: File, replaceOptionState: inout ReplaceOptionState) throws {
            if replaceOptionState.replaceAll == true && replaceOptionState.replaceNone == true {
                assert(false)
            }

            if replaceOptionState.replaceNone {
                return
            }

            var shouldCopy = true

            if destination.containsFile(named: file.name) && replaceOptionState.replaceAll == false {
                let prompt = String.warning("File \(file.name.bold) already exists at \(destination.path)" + "\nDo you want to replace it with the one you just installed?".bold) + ReplaceOption.description

                let option = Reader<ReplaceOption>.readLine(prompt: prompt)

                switch option {
                case .yes:
                    shouldCopy = true
                case .no:
                    shouldCopy = false
                case .replaceAll:
                    replaceOptionState.replaceAll = true
                    shouldCopy = true
                case .replaceNone:
                    replaceOptionState.replaceNone = true
                    shouldCopy = false
                }
            }

            if replaceOptionState.replaceAll || shouldCopy {
                Print.info("Copying \(file.name) into commands folder...")
                if destination.containsFile(named: file.name) {
                    try destination.file(named: file.name).delete()
                }
                try file.copy(to: destination)
                try didCopyFileCompletion(file)
            }

        }

        if let subset = subset, !subset.isEmpty {
            let filteredFiles = validFiles.filter {
                return subset.contains($0.name) || subset.contains($0.nameExcludingExtension)
            }

            if filteredFiles.isEmpty {
                throw CLI.Error(message: String.error("Could not find \(subset) in given repo"))
            }

            try filteredFiles.forEach {
                try copyFile($0, replaceOptionState: &replaceOptionState)
            }
        } else {
            try validFiles.forEach {
                try copyFile($0, replaceOptionState: &replaceOptionState)
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

    private func createManifestFileIfNeeded(in folder: Folder) throws -> File {
        if folder.containsFile(named: "manifest.json") {
            return try folder.file(named: "manifest.json")
        } else {
            return try folder.createFile(named: "manifest.json")
        }
    }

    private func getManifest(from file: File) throws -> ManifestV2 {

        let newManifest: ManifestV2

        do {
            newManifest = try JSONDecoder().decode(ManifestV2.self, from: try file.read())
        } catch {
            do {
                let oldManifest = try JSONDecoder().decode(ManifestV1.self, from: try file.read())
                newManifest = ManifestV2(commands: oldManifest.commands, lldbInit: [])
            } catch {
                newManifest = ManifestV2(commands: [], lldbInit: [])
            }
        }

        return newManifest
    }

    private func writeToManifestFile(manifest: ManifestV2, file: File) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(manifest)
        try file.write(data)
    }

    private func saveToManifestFile(inFolder commandsFolder: Folder, fileToSave: File, source: String, commit: String) throws {

        let manifestFile = try createManifestFileIfNeeded(in: commandsFolder)

        var manifest = try getManifest(from: manifestFile)

        let newCommand = Command(name: fileToSave.nameExcludingExtension, source: source, commit: commit)

        if let index = manifest.commands.firstIndex(where: { $0.name == newCommand.name && $0.source == newCommand.source }) {
            manifest.commands[index] = newCommand
        } else {
            manifest.commands.append(newCommand)
        }

        try writeToManifestFile(manifest: manifest, file: manifestFile)

    }

    private func deleteFiles(in folder: Folder, subset: [String], own: Bool) throws -> Bool {

        func deleteFile(_ file: File) throws {
            if try file.isLLDBScript() {
                Print.info("Deleting \(file.name)...")
                try file.delete()
            }
        }

        var didDelete = false

        func searchAndDeleteInFolder(_ folder: Folder) throws {
            let files = folder.files
            if !subset.isEmpty {
                let subsetCommands = files.filter {
                    return subset.contains($0.nameExcludingExtension)
                }
                try subsetCommands.forEach{
                    try deleteFile($0)
                    didDelete = true
                }
            } else {
                try files.forEach{
                    try deleteFile($0)
                    didDelete = true
                }
            }
            if folder.isEmpty() && !own {
                try folder.delete()
                didDelete = true
            }
        }

        try searchAndDeleteInFolder(folder)

        for folder in folder.subfolders.recursive {
            try searchAndDeleteInFolder(folder)
        }

        return didDelete

    }

    private func createEnvironmentFile() throws {

        let localFolder = try Current.localFolder()

        let lowmadFolder = try localFolder.subfolder(at: "\(Lowmad.name)")

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

        let ownCommandsFolder: Folder

        if installationPath.isEmpty {
            ownCommandsFolder = try lowmadFolder.createSubfolder(at: "own_commands")
        } else {
            ownCommandsFolder = try Folder(path: installationPath)
        }

        let environmentFile = try localFolder.subfolder(named: Lowmad.name).createFile(named: "environment.json")
        let environment = Environment(ownCommandsPath: ownCommandsFolder.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(environment)
        try environmentFile.write(data)

    }

}
