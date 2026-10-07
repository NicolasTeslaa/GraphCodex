import Foundation

enum CodexExecutableLocator {
    static func candidates(appResourcesPath: String?, pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]) -> [String] {
        var paths: [String] = []
        if let appResourcesPath {
            paths.append(URL(fileURLWithPath: appResourcesPath).appendingPathComponent("codex").path)
            paths.append(URL(fileURLWithPath: appResourcesPath)
                .appendingPathComponent("codex-cli/CodexCLI.app/Contents/MacOS/codex").path)
        }
        paths += ["/Applications/ChatGPT.app/Contents/Resources/codex",
                  "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
                  "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        if let pathEnvironment {
            paths += pathEnvironment.split(separator: ":").map { String($0) + "/codex" }
        }
        var seen: Set<String> = []
        return paths.filter { seen.insert($0).inserted }
    }

    static func locate(appResourcesPath: String?, pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
                       isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> String? {
        candidates(appResourcesPath: appResourcesPath, pathEnvironment: pathEnvironment).first(where: isExecutable)
    }
}
