import SwiftUI

private enum Palette {
    static let ink = Color(hex: 0x111420)
    static let panel = Color(hex: 0x1B2030)
    static let raised = Color(hex: 0x252B3E)
    static let muted = Color(hex: 0x929CB4)
    static let line = Color(hex: 0x333B50)
    static let lilac = Color(hex: 0xB2A3FF)
    static let mint = Color(hex: 0x73E1B5)
    static let coral = Color(hex: 0xFF7A68)
    static let gold = Color(hex: 0xF4C86A)
}

struct MainView: View {
    @ObservedObject var monitor: CodexMonitor
    @State private var filter: SessionFilter = .current
    @State private var searchText = ""

    private var visibleSessions: [CodexSession] {
        monitor.sessions
            .filter(filter.includes)
            .filter { searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) || $0.project.localizedCaseInsensitiveContains(searchText) }
            .sorted {
                if $0.state == .attention && $1.state != .attention { return true }
                if $1.state == .attention && $0.state != .attention { return false }
                return $0.updatedAt > $1.updatedAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Palette.line.opacity(0.65)).frame(height: 1)

            if let error = monitor.connectionError {
                connectionBanner(error)
            }

            worldPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .background(Palette.ink)
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x786CDB)).frame(width: 38, height: 38)
                PixelMark().fill(Color(hex: 0xF7F0FF)).frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("GraphCodex").font(.system(size: 17, weight: .bold, design: .rounded))
                Text("sua oficina de agentes").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted)
            }

            Spacer()

            HStack(spacing: 7) {
                CounterChip(value: monitor.currentCount, label: "NO MAPA", color: Palette.lilac)
                CounterChip(value: monitor.workingCount, label: "ATIVAS", color: Palette.mint)
                CounterChip(value: monitor.attentionCount, label: "ATENÇÃO", color: Palette.coral)
            }

            Spacer()

            Button {
                Task { await monitor.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 34, height: 34)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("Atualizar sessões")

            SettingsLink {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 34, height: 34)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("Preferências")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Color(hex: 0x171B28))
    }

    private var worldPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("Buscar projeto ou sessão", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 11).frame(height: 34)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 9))

                Picker("Filtro", selection: $filter) {
                    ForEach(SessionFilter.allCases) { option in Text(option.rawValue).tag(option) }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                HStack(spacing: 7) {
                    Image(systemName: monitor.isRefreshing ? "arrow.triangle.2.circlepath" : "circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(monitor.connectionError == nil ? Palette.mint : Palette.coral)
                    Text(monitor.connectionError == nil ? "AO VIVO" : "SEM CONEXÃO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(monitor.connectionError == nil ? Palette.mint : Palette.coral)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Palette.panel, in: Capsule())
            }

            ZStack {
                Office3DView(
                    sessions: Array(visibleSessions.prefix(120)),
                    selectedSessionID: monitor.selectedSessionID,
                    onSelect: monitor.open
                )
                if visibleSessions.isEmpty {
                    emptyState
                        .padding(20)
                        .background(Color(hex: 0x171B28).opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                        .allowsHitTesting(false)
                }
                HStack(spacing: 6) {
                    Image(systemName: "rotate.3d").foregroundStyle(Palette.lilac)
                    Text("WASD / SETAS: ANDAR · MOUSE PRESO ENQUANTO ANDA · V: 1ª PESSOA · MOUSE: OLHAR · SCROLL: ZOOM · GRADE 5×5")
                        .foregroundStyle(Palette.muted)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color(hex: 0x171B28).opacity(0.82), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("▧   ▧   ▧").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundStyle(Palette.lilac.opacity(0.8))
            Text(monitor.connectionError == nil ? "A oficina está tranquila" : "Conectando ao Codex…")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(monitor.connectionError == nil ? "As sessões recentes vão aparecer aqui." : "O GraphCodex está buscando suas sessões locais.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }

    private func connectionBanner(_ error: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.gold)
            Text(error).font(.system(size: 11)).foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button("Tentar de novo") { Task { await monitor.refresh() } }
                .font(.system(size: 10, weight: .bold)).buttonStyle(.plain).foregroundStyle(Palette.lilac)
        }
        .padding(.horizontal, 20).padding(.vertical, 9)
        .background(Color(hex: 0x392A2A))
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Palette.mint)
            Text("DADOS LOCAIS · SOMENTE LEITURA")
                .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.muted)
            Spacer()
            Text(monitor.lastUpdated.map { "Atualizado às \($0.formatted(date: .omitted, time: .shortened))" } ?? "Aguardando primeira leitura")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 20).padding(.vertical, 9)
        .background(Color(hex: 0x171B28))
    }
}

private struct CounterChip: View {
    let value: Int
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 7) {
            Text("\(value)").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.7).foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PixelMark: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 5
        let cells: [(Int, Int)] = [(1,0),(2,0),(3,0),(0,1),(1,1),(3,1),(4,1),(0,2),(2,2),(4,2),(0,3),(1,3),(3,3),(4,3),(1,4),(2,4),(3,4)]
        var path = Path()
        for (x,y) in cells { path.addRect(CGRect(x: rect.minX + CGFloat(x) * unit, y: rect.minY + CGFloat(y) * unit, width: unit - 1, height: unit - 1)) }
        return path
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: CodexMonitor
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Preferências").font(.system(size: 22, weight: .bold, design: .rounded))
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text("Atualização"); Spacer(); Text("a cada \(Int(monitor.refreshInterval)) s").foregroundStyle(Palette.muted) }
                Slider(value: Binding(get: { monitor.refreshInterval }, set: monitor.updateRefreshInterval), in: 5...30, step: 5)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text("Aviso de inatividade"); Spacer(); Text("\(Int(monitor.inactivityMinutes)) min").foregroundStyle(Palette.muted) }
                Slider(value: Binding(get: { monitor.inactivityMinutes }, set: monitor.updateInactivityMinutes), in: 1...20, step: 1)
            }
            Label("O GraphCodex consulta metadados locais e não grava dados nas sessões.", systemImage: "lock.shield.fill")
                .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ink)
        .foregroundStyle(.white)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
