import SwiftUI

struct ProjectEditor: View {
    let existing: Project?
    let onSave: (Project) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var summary: String
    @State private var instructions: String
    @State private var icon: String
    @State private var kind: ProjectKind
    @State private var tags: String
    @State private var color: Color

    init(existing: Project? = nil, onSave: @escaping (Project) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _summary = State(initialValue: existing?.description ?? "")
        _instructions = State(initialValue: existing?.instructions ?? "")
        _icon = State(initialValue: existing?.icon ?? "square.stack.3d.up.fill")
        _kind = State(initialValue: existing?.kind ?? .general)
        _tags = State(initialValue: existing?.tags.joined(separator: ", ") ?? "")
        _color = State(initialValue: Color(hex: existing?.colorHex ?? 0xB2A3FF))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "Novo departamento" : "Editar departamento")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Form {
                TextField("Nome", text: $name)
                TextField("Descrição curta", text: $summary)
                Picker("Tipo", selection: $kind) { ForEach(ProjectKind.allCases) { Text($0.title).tag($0) } }
                TextField("Ícone SF Symbol", text: $icon)
                TextField("Tags, separadas por vírgula", text: $tags)
                ColorPicker("Acento visual", selection: $color)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instruções do departamento").font(.caption).foregroundStyle(GraphCodexTheme.muted)
                    TextEditor(text: $instructions).font(.system(size: 12)).frame(minHeight: 110)
                        .scrollContentBackground(.hidden).background(GraphCodexTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            HStack {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salvar departamento", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560, height: 560)
        .background(GraphCodexTheme.background)
        .foregroundStyle(GraphCodexTheme.text)
    }

    private func save() {
        let colorHex = NSColor(color).usingColorSpace(.deviceRGB).map {
            (UInt32($0.redComponent * 255) << 16) | (UInt32($0.greenComponent * 255) << 8) | UInt32($0.blueComponent * 255)
        } ?? 0xB2A3FF
        let project = Project(id: existing?.id ?? UUID().uuidString,
                              name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                              description: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                              instructions: instructions, colorHex: colorHex,
                              icon: icon.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind,
                              tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        onSave(project)
        dismiss()
    }
}
