import Foundation

final class GraphCodexWorkspaceRepository {
    private let store: GraphCodexStore
    private(set) var snapshot: GraphCodexSnapshot

    init(store: GraphCodexStore = GraphCodexStore()) throws {
        self.store = store
        self.snapshot = try store.load()
    }

    func saveProject(_ project: Project) throws {
        var updated = snapshot
        if let index = updated.projects.firstIndex(where: { $0.id == project.id }) {
            updated.projects[index] = project
        } else {
            updated.projects.append(project)
        }
        try commit(updated)
    }

    func assign(sessionID: String, to projectID: String?) throws {
        try updateMetadata(for: sessionID) { $0.projectOverrideID = projectID }
    }

    func updateMetadata(for sessionID: String, _ update: (inout SessionMetadata) -> Void) throws {
        var updated = snapshot
        var metadata = updated.sessionMetadata[sessionID] ?? SessionMetadata()
        update(&metadata)
        updated.sessionMetadata[sessionID] = metadata
        try commit(updated)
    }

    func saveLayout(_ layout: OfficeLayout) throws {
        var updated = snapshot
        updated.officeLayout = layout
        try commit(updated)
    }

    func savePreferences(_ preferences: GraphCodexPreferences) throws {
        var updated = snapshot
        updated.preferences = preferences
        try commit(updated)
    }

    private func commit(_ updated: GraphCodexSnapshot) throws {
        try store.save(updated)
        snapshot = updated
    }
}
