import SwiftUI

enum GraphCodexTheme {
    static let background = Color(hex: 0x111420)
    static let surface = Color(hex: 0x1B2030)
    static let raised = Color(hex: 0x252B3E)
    static let muted = Color(hex: 0xAEB7C8)
    static let line = Color(hex: 0x333B50)
    static let primary = Color(hex: 0xB2A3FF)
    static let working = Color(hex: 0x73E1B5)
    static let attention = Color(hex: 0xFF7A68)
    static let quiet = Color(hex: 0xF4C86A)
    static let text = Color(hex: 0xF2F4FA)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

extension SessionState {
    var tint: Color { Color(hex: colorHex) }
}
