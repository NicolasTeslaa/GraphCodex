import Foundation

enum PromptCompositionError: LocalizedError {
    case fileOutsideWorkingDirectory(String)

    var errorDescription: String? {
        switch self {
        case .fileOutsideWorkingDirectory(let path):
            "O arquivo selecionado está fora da pasta de trabalho escolhida: \(path)"
        }
    }
}

enum PromptTemplateBuilder {
    static func build(draft: AgentDraft, project: Project?) throws -> String {
        var sections = [
            "# Agent: \(draft.name.trimmingCharacters(in: .whitespacesAndNewlines))",
            "Papel: \(draft.role.title)",
            "Prioridade: \(draft.priority.title)",
            "Objetivo: \(draft.goal.trimmingCharacters(in: .whitespacesAndNewlines))",
            "Pasta de trabalho: \(draft.workingDirectory)"
        ]

        switch draft.contextSource {
        case .blank:
            break
        case .template(let template):
            sections.append("## Orientação inicial\n\(template.instruction)")
        case .project(let selectedFilePaths):
            let instructions = project?.instructions.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !instructions.isEmpty { sections.append("## Instruções do departamento\n\(instructions)") }
            let files = try selectedFilePaths.map { path -> String in
                guard isWithin(path: path, directory: draft.workingDirectory) else {
                    throw PromptCompositionError.fileOutsideWorkingDirectory(path)
                }
                return URL(fileURLWithPath: path).standardizedFileURL.path
            }
            if !files.isEmpty {
                sections.append("## Arquivos de contexto\nLeia estes arquivos antes de começar:\n" + files.map { "- \($0)" }.joined(separator: "\n"))
            }
        case .cloneFullHistory:
            sections.append("## Contexto clonado\nContinue a conversa clonada a partir do histórico completo.")
        case .cloneSummary(_, let summary):
            sections.append("## Resumo do contexto clonado\n\(summary)")
        }

        let extra = draft.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { sections.append("## Instruções adicionais\n\(extra)") }
        return sections.joined(separator: "\n\n")
    }

    static func isWithin(path: String, directory: String) -> Bool {
        let root = URL(fileURLWithPath: directory).standardizedFileURL.resolvingSymlinksInPath().path
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        return candidate == root || candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
