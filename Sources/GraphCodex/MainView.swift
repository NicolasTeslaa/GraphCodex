import AppKit
import SwiftUI

struct MainView: View {
    @ObservedObject var monitor: CodexMonitor
    @State private var searchText = ""
    @State private var stateFilter: SessionFilter = .all
    @State private var showingNewAgent = false
    @State private var showingNewProject = false
    @State private var duplicateSource: CodexSession?
    @State private var cameraMode: CameraMode = .overview

    private var groups: [ProjectGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return monitor.projectGroups.compactMap { group in
            let sessions = group.sessions.filter { session in
                let matchesState = stateFilter.includes(session)
                let matchesQuery = query.isEmpty || [session.displayName, session.cwd, session.project,
                                                       session.promptSummary ?? "", group.project.name,
                                                       group.project.tags.joined(separator: " ")]
                    .joined(separator: " ").localizedCaseInsensitiveContains(query)
                return matchesState && matchesQuery
            }
            guard query.isEmpty || !sessions.isEmpty || group.sessions.isEmpty else { return nil }
            return ProjectGroup(project: group.project, sessions: sessions)
        }
    }

    private var attentionSessions: [CodexSession] {
        monitor.sessions.filter { $0.state == .attention }
            .filter { sessionFilterMatchesSearch(session: $0) }
    }

    private var focusedGroup: ProjectGroup? { groups.first { $0.id == monitor.selectedProjectID } }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let error = monitor.connectionError { notice(error, color: GraphCodexTheme.attention) }
            if let integrationNotice = monitor.integrationNotice { notice(integrationNotice, color: GraphCodexTheme.quiet) }
            HStack(spacing: 0) {
                ProjectSidebar(groups: groups, attentionSessions: attentionSessions,
                               selectedProjectID: monitor.selectedProjectID,
                               onSelectProject: { monitor.focus(project: $0) },
                               onSelectSession: monitor.select)
                    .frame(width: 224)
                Rectangle().fill(GraphCodexTheme.line).frame(width: 1)
                workspace
                if let session = monitor.selectedSession {
                    Rectangle().fill(GraphCodexTheme.line).frame(width: 1)
                    SessionInspector(monitor: monitor, session: session) { duplicateSource = $0; showingNewAgent = true }
                        .frame(width: 292)
                }
            }
            bottomBar
        }
        .background(GraphCodexTheme.background)
        .foregroundStyle(GraphCodexTheme.text)
        .sheet(isPresented: $showingNewAgent, onDismiss: { duplicateSource = nil }) {
            NewAgentFlow(monitor: monitor, initialSession: duplicateSource,
                         initialProjectID: duplicateSource == nil ? monitor.selectedProjectID : nil)
        }
        .sheet(isPresented: $showingNewProject) {
            ProjectEditor { project in
                do { try monitor.saveProject(project) }
                catch { monitor.report(error) }
            }
        }
        .onChange(of: monitor.officeMode) { _, mode in monitor.updateDefaultMode(mode) }
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                Image(systemName: "square.3.layers.3d.fill").font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(GraphCodexTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GraphCodex").font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("ESCRITÓRIO OPERACIONAL").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                        .foregroundStyle(GraphCodexTheme.muted)
                }
                Rectangle().fill(GraphCodexTheme.line).frame(width: 1, height: 28).padding(.horizontal, 3)
                metric("AGENTS", value: monitor.sessions.count, tint: GraphCodexTheme.text)
                metric("ATIVOS", value: monitor.workingCount, tint: GraphCodexTheme.working)
                metric("ATENÇÃO", value: monitor.attentionCount, tint: GraphCodexTheme.attention)
                metric("CONCLUÍDOS", value: monitor.completedCount, tint: GraphCodexTheme.primary)
                Spacer(minLength: 4)
                Button { showingNewProject = true } label: { Label("Departamento", systemImage: "plus") }
                    .buttonStyle(.bordered).controlSize(.small)
                Button { showingNewAgent = true } label: { Label("Novo Agent", systemImage: "person.badge.plus") }
                    .buttonStyle(.borderedProminent).tint(GraphCodexTheme.primary).controlSize(.small)
                Button { Task { await monitor.refresh() } } label: {
                    Image(systemName: monitor.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(.bordered).controlSize(.small).help("Atualizar sessões")
                SettingsLink { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.bordered).controlSize(.small).help("Ajustes")
            }
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(GraphCodexTheme.muted)
                    TextField("Buscar agents, pastas ou departamentos", text: $searchText)
                        .textFieldStyle(.plain).font(.system(size: 11))
                }
                .padding(.horizontal, 9).frame(width: 270, height: 28)
                .background(GraphCodexTheme.raised, in: RoundedRectangle(cornerRadius: 7))
                Picker("Status", selection: $stateFilter) {
                    ForEach(SessionFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 132).controlSize(.small)
                Spacer()
                if monitor.officeMode == .map {
                    Picker("Câmera", selection: $cameraMode) {
                        ForEach(CameraMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(width: 242).controlSize(.small)
                }
                Picker("Visualização", selection: $monitor.officeMode) {
                    ForEach(OfficeMode.allCases) { mode in Label(mode.title, systemImage: mode.symbol).tag(mode) }
                }
                .pickerStyle(.segmented).frame(width: 238).controlSize(.small)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(GraphCodexTheme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(GraphCodexTheme.line).frame(height: 1) }
    }

    @ViewBuilder private var workspace: some View {
        switch monitor.officeMode {
        case .map:
            ZStack(alignment: .bottomTrailing) {
                Office3DView(groups: Array(groups.prefix(120)), selectedSessionID: monitor.selectedSessionID,
                             selectedProjectID: monitor.selectedProjectID, cameraMode: cameraMode,
                             reduceMotion: monitor.reduceMotion,
                             onSelect: monitor.select, onOpen: monitor.open,
                             onSelectProject: { monitor.selectedProjectID = $0.id })
                    .accessibilityLabel("Mapa tridimensional do escritório")
                VStack(alignment: .trailing, spacing: 10) {
                    MiniMapView(groups: groups, selectedProjectID: monitor.selectedProjectID) {
                        monitor.selectedProjectID = $0.id
                    }
                    Label("Clique seleciona · Enter abre no Codex", systemImage: "cursorarrow.click")
                        .font(.system(size: 9)).foregroundStyle(GraphCodexTheme.muted)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(GraphCodexTheme.background.opacity(0.9), in: Capsule())
                }
                .padding(14)
            }
        case .list:
            SessionListView(groups: groups, selectedSessionID: monitor.selectedSessionID,
                            metadata: monitor.metadata(for:), onSelect: monitor.select, onOpen: monitor.open)
        case .focus:
            ProjectFocusView(group: focusedGroup, selectedSessionID: monitor.selectedSessionID,
                             metadata: monitor.metadata(for:), onSelect: monitor.select,
                             onOpen: monitor.open) { project in
                monitor.selectedProjectID = project?.id
                showingNewAgent = true
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Circle().fill(monitor.connectionError == nil ? GraphCodexTheme.working : GraphCodexTheme.attention).frame(width: 6, height: 6)
            Text(monitor.connectionError == nil ? "App-server local" : "Conexão indisponível")
            Text("·").foregroundStyle(GraphCodexTheme.muted)
            Text(monitor.lastUpdated.map { "Atualizado \($0.formatted(date: .omitted, time: .standard))" } ?? "Aguardando dados")
            Spacer()
            Text("Aprovações e permissões são controladas pelo Codex")
        }
        .font(.system(size: 9, design: .monospaced)).foregroundStyle(GraphCodexTheme.muted)
        .padding(.horizontal, 14).padding(.vertical, 7).background(GraphCodexTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(GraphCodexTheme.line).frame(height: 1) }
    }

    private func metric(_ title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)").font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit()).foregroundStyle(tint)
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(GraphCodexTheme.muted)
        }
        .frame(minWidth: 44, alignment: .leading)
    }

    private func notice(_ message: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
            Text(message).font(.system(size: 11)).foregroundStyle(GraphCodexTheme.text).lineLimit(3)
            Spacer()
            Button { monitor.dismissNotice(message) } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(GraphCodexTheme.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(color.opacity(0.1))
    }

    private func sessionFilterMatchesSearch(session: CodexSession) -> Bool {
        searchText.isEmpty || [session.displayName, session.cwd, session.project, session.promptSummary ?? ""]
            .joined(separator: " ").localizedCaseInsensitiveContains(searchText)
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: CodexMonitor
    @State private var soundEnabled = false
    @State private var reduceMotion = false

    var body: some View {
        Form {
            Section("Atualização e atenção") {
                HStack {
                    Text("Intervalo de atualização")
                    Slider(value: Binding(get: { monitor.refreshInterval }, set: monitor.updateRefreshInterval), in: 5...60, step: 1)
                    Text("\(Int(monitor.refreshInterval)) s").monospacedDigit().frame(width: 40)
                }
                HStack {
                    Text("Considerar inativo após")
                    Slider(value: Binding(get: { monitor.inactivityMinutes }, set: monitor.updateInactivityMinutes), in: 1...120, step: 1)
                    Text("\(Int(monitor.inactivityMinutes)) min").monospacedDigit().frame(width: 52)
                }
            }
            Section("Escritório") {
                Picker("Tela inicial", selection: $monitor.officeMode) {
                    ForEach(OfficeMode.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Som discreto quando surgir atenção", isOn: $soundEnabled)
                Toggle("Reduzir movimento", isOn: $reduceMotion)
            }
            Section {
                Text("O GraphCodex nunca aprova ações automaticamente. Modelo, sandbox e permissões continuam sob controle do Codex.")
                    .font(.caption).foregroundStyle(GraphCodexTheme.muted)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .background(GraphCodexTheme.background)
        .onAppear {
            soundEnabled = monitor.soundEnabled
            reduceMotion = monitor.reduceMotion
        }
        .onChange(of: soundEnabled) { _, value in monitor.updateSoundEnabled(value) }
        .onChange(of: reduceMotion) { _, value in monitor.updateReduceMotion(value) }
    }
}
