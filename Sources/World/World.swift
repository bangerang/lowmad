import Foundation
import Files
import SwiftCLI
import Git

#if DEBUG
public var Current = World()
#else
public let Current = World()
#endif

public struct World {
    
    public var git = Git()

    public var localFolder = {
        return try Folder(path: "/usr/local/lib")
    }
    public var lowmadFolder = {
        return try Folder(path: "/usr/local/lib").subfolder(named: "lowmad")
    }
    public var homeFolder = {
        return Folder.home
    }
    public var readLine: (String?, Bool, [Validation<String>], InputReader<String>.ErrorResponse?) -> String = {prompt, secure, validation, errorResponse in
        return Input.readLine(prompt: prompt, secure: secure, validation: validation, errorResponse: errorResponse)
    }
}
