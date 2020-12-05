import XCTest
import Files
import World
@testable import LowmadKit
import class Foundation.Bundle

final class LowmadTests: XCTestCase {

    private lazy var lowmad: Lowmad = {
        return Lowmad()
    }()

    override class func setUp() {
        Current.homeFolder = {
            return Folder.temporary
        }
        Current.readLine = { prompt, secure, validation, errorResponse in
            return ""
        }
        Current.localFolder = {
            return Folder.temporary
        }
    }

    var lowmadFolder: Folder {
        return try! Folder.temporary.subfolder(named: "\(Lowmad.name)")
    }

    func runInitWithCleanup(proceed: () throws -> Void) throws {
        try lowmad.runInit()
        try proceed()
        let globalLLDBinit = try Folder.temporary.file(named: ".lldbinit")

        try globalLLDBinit.delete()
        try lowmadFolder.delete()
    }

    func testInit() throws {
        try runInitWithCleanup {
            XCTAssertTrue(Folder.temporary.containsFile(named: ".lldbinit"))
            let globalLLDBinit = try Folder.temporary.file(named: ".lldbinit")
            XCTAssertTrue(try !globalLLDBinit.readAsString().isEmpty)
            let lowmadFile = try Folder.temporary.file(at: Lowmad.name + "/\(Lowmad.name).py")
            XCTAssertTrue(try !lowmadFile.readAsString().isEmpty)
        }
    }

    func testInstallFromURL() throws {
        try runInitWithCleanup {
            let gitRepoMock = "git@github.com:Foo/LLDB.git"
            let gitCommitMock = "bar"

            Current.git.clone = { gitURL, _ in
                XCTAssert(gitURL == gitRepoMock)
                let tempFolder = try! Folder.temporary.subfolder(at: "\(Lowmad.name)/temp")
                let file = try! tempFolder.createFile(named: "fake.py")
                try! file.write("__lldb_init_module")
                try! tempFolder.createFile(named: "README.md")
            }
            Current.git.getCommit = { _ in
                return gitCommitMock
            }

            try lowmad.runInstall(gitURL: gitRepoMock, subset: [], manifestURL: nil, commit: nil, ownRepo: false)
            XCTAssert(lowmadFolder.containsFile(at: "/commands/Foo-LLDB/fake.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/Foo-LLDB/README.md"))
        }
    }

    func testInstallFromManifest() throws {
        try runInitWithCleanup {
            let gitRepoMock = "git@github.com:Foo/LLDB.git"
            let manifestMock = Manifest(version: "0.1", commands: [Command(name: "Foo", source: gitRepoMock, commit: "1234")])
            let commandsFolder = Folder.temporary
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(manifestMock)
            let file = try commandsFolder.createFile(named: "manifest.json")
            try file.write(data)

            Current.git.clone = { gitURL, location in
                XCTAssert(gitURL == gitRepoMock)
                let folder = try! Folder(path: location!)
                for command in manifestMock.commands {
                    let file = try! folder.createFile(named: command.name + ".py")
                    try! file.write("__lldb_init_module")
                    try! folder.createFile(named: "README.md")
                }
            }

            try lowmad.runInstall(gitURL: nil, subset: [], manifestURL: file.path, commit: nil, ownRepo: false)
            XCTAssert(lowmadFolder.containsFile(at: "/commands/Foo-LLDB/Foo.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/README.md"))
        }
    }

    func testInstallFromURLWithSubset() throws {
        try runInitWithCleanup {
            let gitRepoMock = "git@github.com:Foo/LLDB.git"
            let gitCommitMock = "bar"

            Current.git.clone = { gitURL, _ in
                XCTAssert(gitURL == gitRepoMock)
                let tempFolder = try! Folder.temporary.subfolder(at: "\(Lowmad.name)/temp")
                let file = try! tempFolder.createFile(named: "fake.py")
                let file2 = try! tempFolder.createFile(named: "fake2.py")
                try! file.write("__lldb_init_module")
                try! file2.write("__lldb_init_module")
                try! tempFolder.createFile(named: "README.md")
            }
            Current.git.getCommit = { _ in
                return gitCommitMock
            }

            try lowmad.runInstall(gitURL: gitRepoMock, subset: ["fake"], manifestURL: nil, commit: nil, ownRepo: false)
            XCTAssert(lowmadFolder.containsFile(at: "/commands/Foo-LLDB/fake.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/Foo-LLDB/fake2.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/Foo-LLDB/README.md"))
        }
    }

    static var allTests = [
        ("testInit", testInit,
         "testInstallFromURL", testInstallFromURL,
         "testInstallFromManifest", testInstallFromManifest,
         "testInstallFromURLWithSubset", testInstallFromURLWithSubset)
    ]
}
