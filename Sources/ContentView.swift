import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.18)

                NowPlayingBar()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }

            if state.showHelp {
                HelpOverlay()
                    .transition(.opacity)
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
        .animation(.easeInOut(duration: 0.14), value: state.showHelp)
        .animation(.easeInOut(duration: 0.14), value: state.mode)
    }
}

private struct GlobalShortcuts: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore

    var body: some View {
        // Invisible buttons that register app-wide keyboard shortcuts.
        ZStack {
            Group {
                key("1") { state.switchMode(.stations) }
                key("2") { state.switchMode(.genres) }
                key("3") { state.switchMode(.favorites) }
                key("4") { state.switchMode(.recents) }
                key("?") { state.showHelp.toggle() }
                key("/") { state.requestSearchFocus() }
                key("S") { state.requestSearchFocus() }
                key(.escape) { state.handleEscape() }
            }
            Group {
                key("p") {
                    player.toggle()
                    state.flashStatus(player.isPlaying ? "play" : "pause")
                }
                key(".") { player.stop(); state.flashStatus("stop") }
                key("-") {
                    player.bumpVolume(-0.05)
                    state.flashStatus("vol \(Int(player.volume * 100))")
                }
                key("=") {
                    player.bumpVolume(+0.05)
                    state.flashStatus("vol \(Int(player.volume * 100))")
                }
                key("F") {
                    if let c = player.current {
                        store.toggleFavorite(c)
                        state.flashStatus(store.isFavorite(c) ? "starred" : "unstarred")
                    }
                }
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
