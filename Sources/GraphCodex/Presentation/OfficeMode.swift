import Foundation

enum OfficeMode: String, CaseIterable, Identifiable {
    case map, list, focus
    var id: String { rawValue }

    var title: String {
        switch self {
        case .map: "Mapa"
        case .list: "Lista"
        case .focus: "Foco"
        }
    }

    var symbol: String {
        switch self {
        case .map: "square.3.layers.3d"
        case .list: "list.bullet"
        case .focus: "scope"
        }
    }
}
