import SwiftUI

struct ProjectFocusView: View {
    let group: ProjectGroup?
    let selectedSessionID: String?
    let metadata: (CodexSession) -> SessionMetadata
    let onSelect: (CodexSession) -> Void
    let onOpen: (CodexSession) -> Void
    let onNewAgent: (Project?) -> Void

    var body: some View {
        if let group {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: group.project.icon).font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color(hex: group.project.colorHex)).frame(width: 42, height: 42)
                        .background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(group.project.name).font(.system(size: 23, weight: .bold, design: .rounded))
                        Text(group.project.description.isEmpty ? group.project.kind.title : group.project.description)
                            .font(.system(size: 12)).foregroundStyle(GraphCodexTheme.muted)
                        if !group.project.tags.isEmpty {
                            Text(group.project.tags.joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(GraphCodexTheme.muted)
                        }
                    }
                    Spacer()
                    Button { onNewAgent(group.project) } label: { Label("Novo Agent", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).tint(GraphCodexTheme.primary)
                }
                HStack(spacing: 16) {
                    metric("Agents", value: group.sessions.count, color: GraphCodexTheme.text)
                    metric("Trabalhando", value: group.workingCount, color: GraphCodexTheme.working)
                    metric("Atenção", value: group.attentionCount, color: GraphCodexTheme.attention)
                    metric("Concluídos", value: group.sessions.filter { $0.state == .complete }.count, color: GraphCodexTheme.primary)
                }
                Text("Agents").font(.system(size: 15, weight: .semibold))
                if group.sessions.isEmpty {
                    ContentUnavailableView("Nenhum agent neste departamento", systemImage: "person.3",
                                           description: Text("Crie um agent para ocupar a primeira estação."))
                } else {
                    SessionListView(groups: [group], selectedSessionID: selectedSessionID,
                                    metadata: metadata, onSelect: onSelect, onOpen: onOpen)
                }
                Spacer(minLength: 0)
            }
            .padding(22).background(GraphCodexTheme.background)
        } else {
            ContentUnavailableView("Selecione um departamento", systemImage: "scope",
                                   description: Text("Escolha uma área na barra lateral para ver seus agents e bloqueios."))
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(GraphCodexTheme.background)
        }
    }

    private func metric(_ title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(title).font(.system(size: 10)).foregroundStyle(GraphCodexTheme.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 9))
    }
}
