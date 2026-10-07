import SwiftUI

struct MiniMapView: View {
    let groups: [ProjectGroup]
    let selectedProjectID: String?
    let onSelect: (Project) -> Void

    var body: some View {
        GeometryReader { proxy in
            let footprints = OfficeSceneBuilder.layout(for: groups)
            let extentX = max(1, footprints.values.map { abs($0.center.x) }.max() ?? 1)
            let extentZ = max(1, footprints.values.map { abs($0.center.z) }.max() ?? 1)
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(GraphCodexTheme.background.opacity(0.94))
                ForEach(groups) { group in
                    if let footprint = footprints[group.id] {
                        Button { onSelect(group.project) } label: {
                            Circle().fill(Color(hex: group.project.colorHex))
                                .overlay(Circle().stroke(selectedProjectID == group.id ? .white : .clear, lineWidth: 2))
                                .frame(width: selectedProjectID == group.id ? 12 : 8,
                                       height: selectedProjectID == group.id ? 12 : 8)
                        }
                        .buttonStyle(.plain)
                        .position(x: proxy.size.width / 2 + CGFloat(footprint.center.x / extentX) * proxy.size.width * 0.36,
                                  y: proxy.size.height / 2 + CGFloat(footprint.center.z / extentZ) * proxy.size.height * 0.34)
                        .help(group.project.name)
                    }
                }
                Image(systemName: "location.fill").font(.system(size: 8)).foregroundStyle(GraphCodexTheme.primary)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2).allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(GraphCodexTheme.line, lineWidth: 1))
        }
        .frame(width: 172, height: 112)
        .accessibilityLabel("Mini mapa dos departamentos")
    }
}
