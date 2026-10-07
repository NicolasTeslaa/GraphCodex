import AppKit
import SwiftUI

struct SessionInspector: View {
    @ObservedObject var monitor: CodexMonitor
    let session: CodexSession
    let onDuplicate: (CodexSession) -> Void

    @State private var showArchiveConfirmation = false
    @State private var actionError: String?
    @State private var isArchiving = false

    private var metadata: SessionMetadata { monitor.metadata(for: session) }
    private var group: ProjectGroup? { monitor.projectGroups.first(where: { $0.sessions.contains(where: { $0.id == session.id }) }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Agent").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.7).foregroundStyle(GraphCodexTheme.muted)
                Spacer()
                Button { closeSelection() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(GraphCodexTheme.muted).help("Fechar inspetor")
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(metadata.displayName ?? session.displayName).font(.system(size: 19, weight: .bold, design: .rounded)).lineLimit(3)
                Label(session.state.label, systemImage: session.state.symbol)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(session.state.tint)
                if let reason = session.reason { Text(reason).font(.system(size: 11)).foregroundStyle(GraphCodexTheme.muted).fixedSize(horizontal: false, vertical: true) }
            }

            Divider().overlay(GraphCodexTheme.line)
            detail("Departamento", value: group?.project.name ?? session.project, icon: group?.project.icon ?? "folder")
            detail("Última atividade", value: session.relativeActivity, icon: "clock")
            if let role = metadata.role { detail("Papel", value: role, icon: "person.crop.circle") }
            detail("Pasta real da sessão", value: session.cwd, icon: "folder")

            if let summary = session.promptSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ÚLTIMO PROMPT").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(GraphCodexTheme.muted)
                    Text(summary).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            }

            actionButtons
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Prioridade", systemImage: "flag")
                    Spacer()
                    Picker("Prioridade", selection: priorityBinding) {
                        ForEach(AgentPriority.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden().frame(width: 110)
                }
                HStack {
                    Label("Mover para", systemImage: "arrowshape.turn.up.right")
                    Spacer()
                    Picker("Mover para", selection: projectBinding) {
                        Text("Pasta automática").tag("")
                        ForEach(monitor.projectGroups) { group in Text(group.project.name).tag(group.id) }
                    }
                    .labelsHidden().frame(width: 155)
                }
            }
            .font(.system(size: 11)).padding(11).background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 9))

            if let actionError { Text(actionError).font(.system(size: 10)).foregroundStyle(GraphCodexTheme.attention).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
            Button(role: .destructive) { showArchiveConfirmation = true } label: {
                Label(isArchiving ? "Arquivando…" : "Arquivar sessão", systemImage: "archivebox")
            }
            .disabled(isArchiving)
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GraphCodexTheme.surface)
        .confirmationDialog("Arquivar esta sessão?", isPresented: $showArchiveConfirmation, titleVisibility: .visible) {
            Button("Arquivar", role: .destructive, action: archive)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A conversa continuará no Codex, mas sairá da lista de sessões abertas do GraphCodex.")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 7) {
            Button { monitor.open(session) } label: { Label("Abrir conversa no Codex", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(GraphCodexTheme.primary)
                .keyboardShortcut(.return, modifiers: [])
            HStack(spacing: 7) {
                Button(action: copyThreadID) { Label("Copiar ID", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                Button { perform { try monitor.toggleFavorite(for: session) } } label: {
                    Label(metadata.isFavorite ? "Favorito" : "Favoritar", systemImage: metadata.isFavorite ? "star.fill" : "star")
                        .frame(maxWidth: .infinity)
                }
                Button { onDuplicate(session) } label: { Label("Duplicar", systemImage: "plus.square.on.square").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private var priorityBinding: Binding<Int> {
        Binding(get: { metadata.priority }, set: { value in perform { try monitor.setPriority(value, for: session) } })
    }

    private var projectBinding: Binding<String> {
        Binding(get: { metadata.projectOverrideID ?? "" }, set: { value in
            perform { try monitor.assign(session, to: value.isEmpty ? nil : value) }
        })
    }

    private func detail(_ title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(GraphCodexTheme.muted).frame(width: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(GraphCodexTheme.muted)
                Text(value).font(.system(size: 11)).lineLimit(3).textSelection(.enabled)
            }
        }
    }

    private func copyThreadID() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.id, forType: .string)
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); actionError = nil }
        catch { actionError = error.localizedDescription }
    }

    private func archive() {
        isArchiving = true
        Task {
            do { try await monitor.archive(session); closeSelection() }
            catch { actionError = error.localizedDescription }
            isArchiving = false
        }
    }

    private func closeSelection() {
        monitor.selectedSessionID = nil
    }
}
