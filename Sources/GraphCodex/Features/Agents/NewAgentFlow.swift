import AppKit
import SwiftUI

private enum AgentContextChoice: String, CaseIterable, Identifiable {
    case blank, template, project, cloneFull, cloneSummary
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blank: "Começar do zero"
        case .template: "Usar template"
        case .project: "Contexto do departamento"
        case .cloneFull: "Clonar histórico completo"
        case .cloneSummary: "Clonar resumo"
        }
    }
}

struct NewAgentFlow: View {
    @ObservedObject var monitor: CodexMonitor
    var initialSession: CodexSession?
    var initialProjectID: String?

    @Environment(\.dismiss) private var dismiss
    @State private var stage = 0
    @State private var selectedProjectID = ""
    @State private var createProject = false
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var projectInstructions = ""
    @State private var projectKind: ProjectKind = .general
    @State private var projectColor = Color(hex: 0xB2A3FF)
    @State private var name = ""
    @State private var goal = ""
    @State private var role: AgentRole = .generalist
    @State private var priority: AgentPriority = .normal
    @State private var tags = ""
    @State private var workingDirectory = ""
    @State private var contextChoice: AgentContextChoice = .blank
    @State private var template: AgentTemplate = .implementFeature
    @State private var selectedFiles: [String] = []
    @State private var sourceThreadID = ""
    @State private var cloneSummary = ""
    @State private var reviewedPrompt = ""
    @State private var isStarting = false
    @State private var errorMessage: String?

    private var availableProjects: [Project] { monitor.projectGroups.map(\.project) }
    private var selectedProject: Project? {
        if createProject {
            return Project(id: selectedProjectID.isEmpty ? "draft-project" : selectedProjectID,
                           name: projectName, description: projectDescription,
                           instructions: projectInstructions, kind: projectKind,
                           workingDirectory: nil, isAutomaticallyGrouped: false)
        }
        return availableProjects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(GraphCodexTheme.line)
            Group {
                switch stage {
                case 0: projectStage
                case 1: agentStage
                case 2: contextStage
                default: reviewStage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .frame(width: 760, height: 700)
        .background(GraphCodexTheme.background)
        .foregroundStyle(GraphCodexTheme.text)
        .onAppear(perform: prepareInitialValues)
        .onChange(of: selectedProjectID) { _, _ in selectedFiles = [] }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Novo Agent").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Escolha o departamento, a pasta e o contexto de partida.")
                        .font(.system(size: 12)).foregroundStyle(GraphCodexTheme.muted)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 8) {
                ForEach(Array(["Departamento", "Agent", "Contexto", "Revisão"].enumerated()), id: \.offset) { index, title in
                    HStack(spacing: 7) {
                        Circle().fill(index <= stage ? GraphCodexTheme.primary : GraphCodexTheme.line).frame(width: 7, height: 7)
                        Text(title).foregroundStyle(index == stage ? GraphCodexTheme.text : GraphCodexTheme.muted)
                    }
                    .font(.system(size: 11, weight: index == stage ? .semibold : .regular))
                    if index < 3 { Rectangle().fill(GraphCodexTheme.line).frame(height: 1).frame(maxWidth: 54) }
                }
            }
        }
        .padding(22)
    }

    private var projectStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Onde este agent vai trabalhar?").font(.system(size: 18, weight: .semibold))
            Picker("Departamento", selection: $createProject) {
                Text("Existente").tag(false)
                Text("Criar novo").tag(true)
            }.pickerStyle(.segmented).frame(maxWidth: 330)
            if createProject {
                Form {
                    TextField("Nome do departamento", text: $projectName)
                    TextField("Descrição", text: $projectDescription)
                    Picker("Tipo", selection: $projectKind) { ForEach(ProjectKind.allCases) { Text($0.title).tag($0) } }
                    ColorPicker("Cor", selection: $projectColor)
                    TextField("Instruções", text: $projectInstructions, axis: .vertical).lineLimit(3...6)
                }.frame(maxWidth: 520)
            } else {
                Picker("Departamento", selection: $selectedProjectID) {
                    Text("Selecione um departamento").tag("")
                    ForEach(availableProjects) { project in Text(project.name).tag(project.id) }
                }
                .frame(maxWidth: 430)
                Text("O departamento é uma área visual. A pasta de trabalho individual será escolhida na próxima etapa.")
                    .font(.system(size: 12)).foregroundStyle(GraphCodexTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(24)
    }

    private var agentStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Defina o papel e o local de trabalho.").font(.system(size: 18, weight: .semibold))
            Form {
                TextField("Nome do agent", text: $name)
                TextField("Objetivo principal", text: $goal)
                Picker("Papel", selection: $role) { ForEach(AgentRole.allCases) { Text($0.title).tag($0) } }
                Picker("Prioridade", selection: $priority) { ForEach(AgentPriority.allCases) { Text($0.title).tag($0) } }
                TextField("Tags, separadas por vírgula", text: $tags)
            }
            HStack(spacing: 10) {
                Image(systemName: "folder.fill").foregroundStyle(GraphCodexTheme.primary)
                Text(workingDirectory.isEmpty ? "Nenhuma pasta escolhida" : workingDirectory)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(GraphCodexTheme.muted).lineLimit(1)
                Spacer()
                Button("Escolher pasta…", action: chooseWorkingDirectory)
            }
            .padding(12).background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            Spacer()
        }
        .padding(24)
    }

    private var contextStage: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Como o agent deve começar?").font(.system(size: 18, weight: .semibold))
            Picker("Contexto inicial", selection: $contextChoice) {
                ForEach(AgentContextChoice.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            if contextChoice == .template {
                Picker("Template", selection: $template) { ForEach(AgentTemplate.allCases) { Text($0.title).tag($0) } }
                    .frame(maxWidth: 430)
            } else if contextChoice == .project {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Instruções do departamento").font(.system(size: 12, weight: .semibold))
                    Text(selectedProject?.instructions.isEmpty == false ? selectedProject!.instructions : "Este departamento não tem instruções salvas.")
                        .font(.system(size: 12)).foregroundStyle(GraphCodexTheme.muted).lineLimit(4)
                    HStack {
                        Button("Escolher arquivos da pasta…", action: chooseContextFiles)
                        Spacer()
                        Text("\(selectedFiles.count) selecionados").font(.system(size: 11)).foregroundStyle(GraphCodexTheme.muted)
                    }
                    ForEach(selectedFiles, id: \.self) { path in Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(GraphCodexTheme.muted).lineLimit(1) }
                }
                .padding(14).background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            } else if contextChoice == .cloneFull || contextChoice == .cloneSummary {
                Picker("Agent de origem", selection: $sourceThreadID) {
                    Text("Selecione uma conversa").tag("")
                    ForEach(monitor.sessions) { session in Text("\(session.displayName) · \(session.project)").tag(session.id) }
                }
                .frame(maxWidth: 540)
                if contextChoice == .cloneSummary {
                    Text("Resumo inicial (editável na revisão)").font(.system(size: 12, weight: .semibold))
                    TextEditor(text: $cloneSummary).frame(minHeight: 88)
                        .scrollContentBackground(.hidden).background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("O primeiro turno terá apenas seu objetivo e as instruções que você editar na revisão.")
                    .font(.system(size: 12)).foregroundStyle(GraphCodexTheme.muted)
            }
            Spacer()
        }
        .padding(24)
    }

    private var reviewStage: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Revise antes de iniciar").font(.system(size: 18, weight: .semibold))
            HStack {
                Label(selectedProject?.name ?? "Departamento", systemImage: selectedProject?.icon ?? "square.stack.3d.up.fill")
                Spacer()
                Label(workingDirectory, systemImage: "folder")
                    .font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
            }
            .padding(12).background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 9))
            HStack {
                Text("Prompt inicial").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Editável").font(.system(size: 10)).foregroundStyle(GraphCodexTheme.muted)
            }
            TextEditor(text: $reviewedPrompt)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(GraphCodexTheme.surface, in: RoundedRectangle(cornerRadius: 9))
            if let errorMessage { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(GraphCodexTheme.attention) }
            Text("O Codex mantém o controle sobre o modelo, o sandbox e as permissões. GraphCodex não aprova ações automaticamente.")
                .font(.system(size: 11)).foregroundStyle(GraphCodexTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
    }

    private var footer: some View {
        HStack {
            if stage > 0 { Button("Voltar") { stage -= 1 } }
            Spacer()
            if stage < 3 {
                Button("Continuar") { advance() }.keyboardShortcut(.defaultAction).disabled(!canAdvance)
            } else {
                Button(isStarting ? "Iniciando…" : "Iniciar Agent", action: startAgent)
                    .keyboardShortcut(.defaultAction).disabled(isStarting || reviewedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .background(GraphCodexTheme.surface)
    }

    private var canAdvance: Bool {
        switch stage {
        case 0: createProject ? !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : !selectedProjectID.isEmpty
        case 1: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validWorkingDirectory
        case 2: contextChoice != .cloneFull && contextChoice != .cloneSummary || !sourceThreadID.isEmpty
        default: true
        }
    }

    private var validWorkingDirectory: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: workingDirectory, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func prepareInitialValues() {
        if let initialProjectID { selectedProjectID = initialProjectID }
        if let initialSession {
            name = "\(initialSession.displayName) (cópia)"
            goal = initialSession.promptSummary ?? "Continue o trabalho a partir do contexto clonado."
            sourceThreadID = initialSession.id
            cloneSummary = initialSession.promptSummary ?? ""
            contextChoice = .cloneFull
            workingDirectory = initialSession.cwd
            selectedProjectID = monitor.metadata(for: initialSession).projectOverrideID
                ?? monitor.projectGroups.first(where: { $0.sessions.contains(where: { $0.id == initialSession.id }) })?.id ?? ""
        } else if let first = availableProjects.first {
            selectedProjectID = first.id
        }
    }

    private func advance() {
        errorMessage = nil
        if stage == 0, createProject {
            let colorHex = NSColor(projectColor).usingColorSpace(.deviceRGB).map {
                (UInt32($0.redComponent * 255) << 16) | (UInt32($0.greenComponent * 255) << 8) | UInt32($0.blueComponent * 255)
            } ?? 0xB2A3FF
            let project = Project(id: UUID().uuidString, name: projectName, description: projectDescription,
                                  instructions: projectInstructions, colorHex: colorHex, kind: projectKind,
                                  workingDirectory: nil, isAutomaticallyGrouped: false)
            do { try monitor.saveProject(project); selectedProjectID = project.id }
            catch { errorMessage = error.localizedDescription; return }
        }
        if stage == 2 {
            do { reviewedPrompt = try PromptTemplateBuilder.build(draft: draft, project: selectedProject) }
            catch { errorMessage = error.localizedDescription; return }
        }
        stage += 1
    }

    private var draft: AgentDraft {
        let source: AgentContextSource
        switch contextChoice {
        case .blank: source = .blank
        case .template: source = .template(template)
        case .project: source = .project(selectedFilePaths: selectedFiles)
        case .cloneFull: source = .cloneFullHistory(threadID: sourceThreadID)
        case .cloneSummary: source = .cloneSummary(threadID: sourceThreadID, summary: cloneSummary)
        }
        return AgentDraft(name: name, goal: goal, role: role, priority: priority,
                          tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                          projectID: selectedProjectID, workingDirectory: workingDirectory,
                          contextSource: source)
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Usar pasta"
        if panel.runModal() == .OK, let url = panel.url { workingDirectory = url.path }
    }

    private func chooseContextFiles() {
        guard validWorkingDirectory else { return }
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: workingDirectory)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Adicionar contexto"
        if panel.runModal() == .OK {
            selectedFiles = (panel.urls.map(\.path) + selectedFiles)
                .filter { PromptTemplateBuilder.isWithin(path: $0, directory: workingDirectory) }
                .uniqued()
        }
    }

    private func startAgent() {
        isStarting = true
        errorMessage = nil
        Task {
            do {
                _ = try await monitor.startAgent(draft, approvedPrompt: reviewedPrompt)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isStarting = false
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}
