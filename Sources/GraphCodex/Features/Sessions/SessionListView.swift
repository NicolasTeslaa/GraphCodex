import SwiftUI

struct SessionListView: View {
    let groups: [ProjectGroup]
    let selectedSessionID: String?
    let metadata: (CodexSession) -> SessionMetadata
    let onSelect: (CodexSession) -> Void
    let onOpen: (CodexSession) -> Void

    private var sessions: [CodexSession] {
        groups.flatMap(\.sessions).sorted {
            if metadata($0).priority != metadata($1).priority { return metadata($0).priority > metadata($1).priority }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Agent").frame(maxWidth: .infinity, alignment: .leading)
                Text("Departamento").frame(width: 170, alignment: .leading)
                Text("Status").frame(width: 160, alignment: .leading)
                Text("Última atividade").frame(width: 120, alignment: .leading)
                Image(systemName: "star.fill").frame(width: 22)
            }
            .font(.system(size: 10, weight: .bold)).foregroundStyle(GraphCodexTheme.muted)
            .padding(.horizontal, 14).padding(.vertical, 10)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(sessions) { session in
                        Button { onSelect(session) } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        if metadata(session).priority > 0 {
                                            Image(systemName: "flag.fill").font(.system(size: 9)).foregroundStyle(GraphCodexTheme.quiet)
                                        }
                                        Text(session.displayName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    }
                                    Text(session.promptSummary ?? session.cwd).font(.system(size: 10)).foregroundStyle(GraphCodexTheme.muted).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(projectName(for: session)).font(.system(size: 11)).lineLimit(1).frame(width: 170, alignment: .leading)
                                Label(session.state.label, systemImage: session.state.symbol)
                                    .font(.system(size: 10, weight: .medium)).foregroundStyle(session.state.tint)
                                    .frame(width: 160, alignment: .leading).lineLimit(1)
                                Text(session.relativeActivity).font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(GraphCodexTheme.muted).frame(width: 120, alignment: .leading)
                                Image(systemName: metadata(session).isFavorite ? "star.fill" : "")
                                    .font(.system(size: 10)).foregroundStyle(GraphCodexTheme.primary).frame(width: 22)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedSessionID == session.id ? GraphCodexTheme.raised : .clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onTapGesture(count: 2) { onOpen(session) }
                        .accessibilityLabel("\(session.displayName), \(session.state.label)")
                        .accessibilityHint("Duplo clique abre a conversa no Codex")
                    }
                }
                .padding(6)
            }
        }
        .background(GraphCodexTheme.background)
    }

    private func projectName(for session: CodexSession) -> String {
        groups.first(where: { $0.sessions.contains(where: { $0.id == session.id }) })?.project.name ?? session.project
    }
}
