import XCTest
@testable import GraphCodex

final class WorkspaceRepositoryTests: XCTestCase {
    func testOfficePreferencesSurviveReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraphCodexPreferences-\(UUID().uuidString)")
            .appendingPathComponent("graphcodex.json")
        let store = GraphCodexStore(fileURL: url)
        let repository = try GraphCodexWorkspaceRepository(store: store)
        let preferences = GraphCodexPreferences(inactivityMinutes: 12, defaultMode: "focus",
                                                soundEnabled: true, reduceMotion: true)

        try repository.savePreferences(preferences)

        XCTAssertEqual(try GraphCodexWorkspaceRepository(store: store).snapshot.preferences, preferences)
    }

    func testThreadAssignmentAndPrioritySurviveReloadWithoutChangingSessionFolder() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraphCodexRepository-\(UUID().uuidString)")
            .appendingPathComponent("graphcodex.json")
        let store = GraphCodexStore(fileURL: url)
        let project = Project(id: "dose-certa", name: "Dose Certa", kind: .product)
        try store.save(GraphCodexSnapshot(projects: [project]))
        let session = CodexSession(id: "thread-1", name: "Agent", cwd: "/work/GraphCodex",
                                   updatedAt: .now, state: .working, reason: nil,
                                   project: "GraphCodex", promptSummary: nil)
        let repository = try GraphCodexWorkspaceRepository(store: store)

        try repository.assign(sessionID: session.id, to: project.id)
        try repository.updateMetadata(for: session.id) { $0.priority = 3; $0.isFavorite = true }

        let reloaded = try GraphCodexWorkspaceRepository(store: store)
        let groups = SessionOrganizer.group([session], projects: reloaded.snapshot.projects,
                                             metadata: reloaded.snapshot.sessionMetadata)
        XCTAssertEqual(groups.map(\.project.id), ["dose-certa"])
        XCTAssertEqual(groups[0].sessions[0].cwd, "/work/GraphCodex")
        XCTAssertEqual(reloaded.snapshot.sessionMetadata[session.id]?.priority, 3)
        XCTAssertEqual(reloaded.snapshot.sessionMetadata[session.id]?.isFavorite, true)
    }
}
