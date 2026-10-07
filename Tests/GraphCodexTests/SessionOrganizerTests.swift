import XCTest
@testable import GraphCodex

final class SessionOrganizerTests: XCTestCase {
    func testGroupsSessionsByCanonicalWorkingFolder() {
        let sessions = [session("one", cwd: "/Users/a/Repos/GraphCodex/../GraphCodex"),
                        session("two", cwd: "/Users/a/Repos/GraphCodex")]

        let groups = SessionOrganizer.group(sessions, metadata: [:])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].project.id, "/Users/a/Repos/GraphCodex")
        XCTAssertEqual(Set(groups[0].sessions.map(\.id)), ["one", "two"])
    }

    func testDuplicateFolderNamesIncludeParentInDisplayName() {
        let sessions = [session("one", cwd: "/Users/a/Repos/GraphCodex"),
                        session("two", cwd: "/Users/b/Repos/GraphCodex")]

        let groups = SessionOrganizer.group(sessions, metadata: [:])

        XCTAssertEqual(Set(groups.map(\.project.name)), ["a/Repos/GraphCodex", "b/Repos/GraphCodex"])
    }

    func testManualAssignmentOverridesGroupingWithoutChangingSessionWorkingFolder() {
        let session = session("one", cwd: "/Users/a/Repos/GraphCodex")
        let department = Project(id: "verval", name: "Verval", kind: .client)
        let metadata = [session.id: SessionMetadata(projectOverrideID: department.id)]

        let groups = SessionOrganizer.group([session], projects: [department], metadata: metadata)

        XCTAssertEqual(groups.map(\.project.id), ["verval"])
        XCTAssertEqual(groups[0].sessions[0].cwd, "/Users/a/Repos/GraphCodex")
    }

    private func session(_ id: String, cwd: String) -> CodexSession {
        CodexSession(id: id, name: nil, cwd: cwd, updatedAt: .distantPast, state: .working,
                     reason: nil, project: URL(fileURLWithPath: cwd).lastPathComponent, promptSummary: nil)
    }
}
