import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore
    @EnvironmentObject var vizSettings: VisualizerSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView()
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                TabStrip()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                Divider().opacity(0.18)

                Group {
                    switch state.mode {
                    case .stations:  TopStationsView()
                    case .search:    SearchView()
                    case .genres:    GenresView()
                    case .favorites: FavoritesView()
                    case .recents:   RecentsView()
                    }
                }
                .id(state.mode)
                .transition(tabTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.18)

                if state.showVisualizer {
                    VisualizerDriver(
                        settings: vizSettings,
                        isPlaying: player.isPlaying,
                        volume: player.volume
                    )
                    .frame(height: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                        )
                    )
                }

                NowPlayingBar()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }

            if state.showHelp {
                HelpOverlay()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        )
                    )
            }
        }
        .background(
            ZStack {
                Color.clear.background(.ultraThickMaterial)
                LinearGradient(
                    colors: [Color.black.opacity(0.03), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        )
        .background(GlobalShortcuts())
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.22, extraBounce: 0.06), value: state.showHelp)
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.28, extraBounce: 0.08), value: state.mode)
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.24, extraBounce: 0.06), value: state.showVisualizer)
    }

    private var tabTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        if state.modeShiftDirection == AppState.noModeShiftDirection {
            return .opacity
        }
        let insertionEdge: Edge = state.modeShiftDirection >= 0 ? .trailing : .leading
        let removalEdge: Edge = state.modeShiftDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

private struct GlobalShortcuts: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore
    @EnvironmentObject var vizSettings: VisualizerSettings

    var body: some View {
        // Invisible buttons that register app-wide keyboard shortcuts.
        ZStack {
            Group {
                // A8: guard most shortcuts when help is shown
                guardedKey("1") { state.switchMode(.stations) }
                guardedKey("2") { state.switchMode(.genres) }
                guardedKey("3") { state.switchMode(.favorites) }
                guardedKey("4") { state.switchMode(.recents) }
                key("?") { state.showHelp.toggle() }
                guardedKey("/") { state.requestSearchFocus() }
                guardedKey("S") { state.requestSearchFocus() }
                key(.escape) { state.handleEscape() }
            }
            Group {
                guardedKey("p") {
                    player.toggle()
                    state.flashStatus(player.isPlaying ? "play" : "pause")
                }
                guardedKey(".") { player.stop(); state.flashStatus("stop") }
                guardedKey("-") {
                    player.bumpVolume(-0.05)
                    state.flashStatus("vol \(Int(player.volume * 100))")
                }
                guardedKey("=") {
                    player.bumpVolume(+0.05)
                    state.flashStatus("vol \(Int(player.volume * 100))")
                }
                guardedKey("F") {
                    if let c = player.current {
                        store.toggleFavorite(c)
                        state.flashStatus(store.isFavorite(c) ? "starred" : "unstarred")
                    }
                }
                guardedKey("v") {
                    state.showVisualizer.toggle()
                    state.flashStatus(state.showVisualizer ? "viz on" : "viz off")
                }
            }
            Group {
                // A6: Shift+V to cycle visualizer preset
                guardedKey("V") {
                    vizSettings.cyclePreset()
                    state.flashStatus(vizSettings.currentPresetName)
                }
                // A7: r to reload current tab
                guardedKey("r") {
                    state.requestReload()
                    state.flashStatus("reload")
                }
                // A4: Tab / Shift+Tab to cycle all sections including search
                Button(action: {
                    guard !state.showHelp else { return }
                    state.moveSectionAll(+1)
                }) { EmptyView() }
                    .keyboardShortcut(.tab, modifiers: [])
                    .buttonStyle(.plain)
                Button(action: {
                    guard !state.showHelp else { return }
                    state.moveSectionAll(-1)
                }) { EmptyView() }
                    .keyboardShortcut(.tab, modifiers: [.shift])
                    .buttonStyle(.plain)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A8: Shortcut that is silently ignored when the help overlay is shown.
    @ViewBuilder
    private func guardedKey(_ s: String, _ action: @escaping () -> Void) -> some View {
        key(s) {
            guard !state.showHelp else { return }
            action()
        }
    }

    @ViewBuilder
    private func key(_ s: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { EmptyView() }
            .keyboardShortcut(KeyEquivalent(Character(s)), modifiers: [])
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private func key(_ k: KeyEquivalent, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { EmptyView() }
            .keyboardShortcut(k, modifiers: [])
            .buttonStyle(.plain)
    }
}
