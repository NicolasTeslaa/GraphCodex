import XCTest
@testable import GraphCodex

final class CodexExecutableLocatorTests: XCTestCase {
    func testBundledCLIPathIsCheckedBesideCodexAppResources() {
        let candidates = CodexExecutableLocator.candidates(appResourcesPath: "/Applications/ChatGPT.app/Contents/Resources")
        XCTAssertTrue(candidates.contains("/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"))
    }
}
