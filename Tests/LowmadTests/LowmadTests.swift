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

            try lowmad.runInstall(gitURL: gitRepoMock, subset: [], commit: nil, ownRepo: false)
            XCTAssert(lowmadFolder.containsFile(at: "/commands/Foo-LLDB/fake.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/Foo-LLDB/README.md"))
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

            try lowmad.runInstall(gitURL: gitRepoMock, subset: ["fake"], commit: nil, ownRepo: false)
            XCTAssert(lowmadFolder.containsFile(at: "/commands/Foo-LLDB/fake.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/Foo-LLDB/fake2.py"))
            XCTAssert(!lowmadFolder.containsFile(at: "/commands/Foo-LLDB/README.md"))
        }
    }

    static var allTests = [
        ("testInit", testInit,
         "testInstallFromURL", testInstallFromURL,
         "testInstallFromURLWithSubset", testInstallFromURLWithSubset)
    ]
}
