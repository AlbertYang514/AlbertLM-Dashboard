import SwiftUI

@main
struct AlbertLMDashboardApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var appModel: AppViewModel

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _appModel = StateObject(wrappedValue: AppViewModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup("AlbertLM Dashboard") {
            ContentView()
                .environmentObject(settings)
                .environmentObject(appModel)
                .environment(\.locale, settings.language.locale)
                .frame(width: 1180, height: 780)
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(appModel)
                .environment(\.locale, settings.language.locale)
                .frame(width: 520)
                .padding()
        }
    }
}
