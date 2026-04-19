import SwiftUI

@main
struct NewRadioApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("NewRadio") {
            ContentView()
                .environmentObject(state)
                .environmentObject(state.player)
                .environmentObject(state.store)
                .environmentObject(state.visualizerSettings)
                .frame(
                    minWidth: 340, idealWidth: 380, maxWidth: 520,
                    minHeight: 460, idealHeight: 560, maxHeight: 820
                )
                .background(WindowAccessor())
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// Strips the default title bar material for a cleaner, widget-like feel.
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.isMovableByWindowBackground = true
            w.backgroundColor = .clear
            w.standardWindowButton(.zoomButton)?.isHidden = true
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
