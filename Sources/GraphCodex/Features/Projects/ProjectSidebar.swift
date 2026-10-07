import SwiftUI

struct ProjectSidebar: View {
    let groups: [ProjectGroup]
    let attentionSessions: [CodexSession]
    let selectedProjectID: String?
    let onSelectProject: (Project) -> Void
    let onSelectSession: (CodexSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle("DEPARTAMENTOS", count: groups.count)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(groups) { group in
                        Button { onSelectProject(group.project) } label: {
                            HStack(spacing: 9) {
                                Image(systemName: group.project.icon).font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(hex: group.project.colorHex)).frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.project.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Text("\(group.sessions.count) agents · \(group.workingCount) ativos")
                                        .font(.system(size: 10)).foregroundStyle(GraphCodexTheme.muted)
                                }
                                Spacer(minLength: 0)
                                if group.attentionCount > 0 {
                                    Text("\(group.attentionCount)").font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(GraphCodexTheme.attention)
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 8)
                            .background(selectedProjectID == group.id ? GraphCodexTheme.raised : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(group.project.description.isEmpty ? group.project.name : group.project.description)
                    }
                }
            }
            Divider().overlay(GraphCodexTheme.line)
            sectionTitle("ATENÇÃO", count: attentionSessions.count)
            if attentionSessions.isEmpty {
                Label("Tudo em dia", systemImage: "checkmark.circle")
                    .font(.system(size: 11)).foregroundStyle(GraphCodexTheme.muted).padding(.vertical, 5)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(attentionSessions.prefix(8)) { session in
                            Button { onSelectSession(session) } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: session.state.symbol).foregroundStyle(session.state.tint).frame(width: 14)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.displayName).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                        Text(session.reason ?? session.project).font(.system(size: 10)).foregroundStyle(GraphCodexTheme.muted).lineLimit(2)
                                    }
                                }
                                .padding(7).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text("GraphCodex · local").font(.system(size: 10, design: .monospaced)).foregroundStyle(GraphCodexTheme.muted)
        }
        .padding(13).background(GraphCodexTheme.surface)
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.8)
            Spacer()
            Text("\(count)").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(GraphCodexTheme.muted)
        }
        .foregroundStyle(GraphCodexTheme.muted)
    }
}
