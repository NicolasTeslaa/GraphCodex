import Foundation

struct OfficePoint: Equatable, Hashable {
    var x: Double
    var z: Double
}

struct DepartmentFootprint: Equatable {
    var projectID: String
    var center: OfficePoint
    var width: Double
    var depth: Double
    var stationPositions: [String: OfficePoint]
}

enum OfficeSceneBuilder {
    static func layout(for groups: [ProjectGroup], placements: [String: DepartmentPlacement] = [:]) -> [String: DepartmentFootprint] {
        let ordered = groups.sorted { $0.project.id < $1.project.id }
        guard !ordered.isEmpty else { return [:] }
        let columns = max(1, Int(ceil(sqrt(Double(ordered.count)))))
        let rows = max(1, Int(ceil(Double(ordered.count) / Double(columns))))

        return Dictionary(uniqueKeysWithValues: ordered.enumerated().map { index, group in
            let column = index % columns
            let row = index / columns
            let center = placements[group.id].map { OfficePoint(x: $0.x, z: $0.z) }
                ?? OfficePoint(x: (Double(column) - Double(columns - 1) / 2) * 22,
                               z: (Double(row) - Double(rows - 1) / 2) * 20)
            let stationColumns = max(1, Int(ceil(sqrt(Double(group.sessions.count)))))
            let stationRows = max(1, Int(ceil(Double(group.sessions.count) / Double(stationColumns))))
            let width = max(12, Double(stationColumns) * 6 + 6)
            let depth = max(11, Double(stationRows) * 6 + 5)
            var stationPositions: [String: OfficePoint] = [:]
            for (stationIndex, session) in group.sessions.sorted(by: { $0.id < $1.id }).enumerated() {
                let x = (Double(stationIndex % stationColumns) - Double(stationColumns - 1) / 2) * 6
                let z = (Double(stationIndex / stationColumns) - Double(stationRows - 1) / 2) * 6 + 1
                stationPositions[session.id] = OfficePoint(x: x, z: z)
            }
            return (group.id, DepartmentFootprint(projectID: group.id, center: center, width: width,
                                                  depth: depth, stationPositions: stationPositions))
        })
    }
}
