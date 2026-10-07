import XCTest
@testable import GraphCodex

final class GraphCodexStoreTests: XCTestCase {
    func testMetadataSurvivesStoreReload() throws {
        let url = temporaryStoreURL()
        let store = GraphCodexStore(fileURL: url)
        let project = Project(id: "verval", name: "Verval", instructions: "Preferir mudanças pequenas", kind: .client)
        let snapshot = GraphCodexSnapshot(
            projects: [project],
            sessionMetadata: ["thread-1": SessionMetadata(projectOverrideID: project.id, priority: 2, isFavorite: true)]
        )

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
    }

    func testUnsupportedNewerSchemaIsNotOverwritten() throws {
        let url = temporaryStoreURL()
        let newerData = Data("{\"schemaVersion\":999,\"projects\":[]}".utf8)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try newerData.write(to: url)

        XCTAssertThrowsError(try GraphCodexStore(fileURL: url).load())
        XCTAssertEqual(try Data(contentsOf: url), newerData)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GraphCodexTests-\(UUID().uuidString)")
            .appendingPathComponent("graphcodex.json")
    }
}
