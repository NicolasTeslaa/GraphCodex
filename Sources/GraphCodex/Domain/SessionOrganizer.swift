import Foundation

enum SessionOrganizer {
    static func group(
        _ sessions: [CodexSession],
        projects: [Project] = [],
        metadata: [String: SessionMetadata]
    ) -> [ProjectGroup] {
        var projectByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        var sessionsByProject: [String: [CodexSession]] = [:]

        for session in sessions {
            let canonicalPath = URL(fileURLWithPath: session.cwd).standardizedFileURL.path
            let automaticProject = Project.automatic(for: canonicalPath)
            let assignedID = metadata[session.id]?.projectOverrideID ?? automaticProject.id

            if projectByID[assignedID] == nil {
                projectByID[assignedID] = assignedID == automaticProject.id
                    ? automaticProject
                    : Project(id: assignedID, name: assignedID)
            }
            sessionsByProject[assignedID, default: []].append(session)
        }

        let duplicateNames = Dictionary(grouping: projectByID.values.filter(\.isAutomaticallyGrouped), by: \.name)
            .filter { $0.value.count > 1 }
        for (name, matches) in duplicateNames {
            let paths = matches.map { project in
                (project, URL(fileURLWithPath: project.workingDirectory ?? "").pathComponents.dropFirst().dropLast())
            }
            let maximumDepth = paths.map { $0.1.count }.max() ?? 1
            for depth in 1...max(1, maximumDepth) {
                let labels = paths.map { project, ancestors in
                    (project.id, (Array(ancestors.suffix(depth)) + [name]).joined(separator: "/"))
                }
                if Set(labels.map(\.1)).count == labels.count {
                    for (id, label) in labels { projectByID[id]?.name = label }
                    break
                }
            }
        }

        return projectByID.values
            .map { ProjectGroup(project: $0, sessions: sessionsByProject[$0.id, default: []].sorted { $0.updatedAt > $1.updatedAt }) }
            .sorted {
                if !$0.sessions.isEmpty && $1.sessions.isEmpty { return true }
                if $0.sessions.isEmpty && !$1.sessions.isEmpty { return false }
                return $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
            }
    }
}
