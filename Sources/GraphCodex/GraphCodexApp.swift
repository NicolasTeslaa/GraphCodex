import AppKit
import SwiftUI

@main
struct GraphCodexApp: App {
    @StateObject private var monitor = CodexMonitor()

    var body: some Scene {
        WindowGroup {
            MainView(monitor: monitor)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(.dark)
                .background(StartupWindowSizer())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)

        Settings {
            SettingsView(monitor: monitor)
                .frame(width: 440, height: 310)
        }
    }
}

private struct StartupWindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowSizingView {
        WindowSizingView()
    }

    func updateNSView(_ nsView: WindowSizingView, context: Context) {}

    final class WindowSizingView: NSView {
        private var didApplyStartupSize = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, !didApplyStartupSize else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      !self.didApplyStartupSize,
                      let window = self.window,
                      let screen = window.screen ?? NSScreen.main else { return }

                // Fill the usable display area; visibleFrame excludes the Dock and menu bar.
                let visibleFrame = screen.visibleFrame
                let size = visibleFrame.size
                let frame = NSRect(
                    x: visibleFrame.midX - size.width / 2,
                    y: visibleFrame.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )

                window.setFrame(frame, display: true, animate: false)
                self.didApplyStartupSize = true
            }
        }
    }
}
