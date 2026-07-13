import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: Self { self }

    var localizationKey: String {
        switch self {
        case .system: "System Default"
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var host: String
    @Published var username: String
    @Published var projectPath: String
    @Published var teacherProjectPath: String
    @Published var language: AppLanguage

    private enum Key {
        static let host = "sshHost"
        static let username = "sshUsername"
        static let projectPath = "projectPath"
        static let teacherProjectPath = "teacherProjectPath"
        static let language = "appLanguage"
    }

    init(defaults: UserDefaults = .standard) {
        host = defaults.string(forKey: Key.host) ?? "ludan2"
        username = defaults.string(forKey: Key.username) ?? ""
        projectPath = defaults.string(forKey: Key.projectPath) ?? "~/AlbertLM"
        teacherProjectPath = defaults.string(forKey: Key.teacherProjectPath) ?? "~/AI-Teachers"
        language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
    }

    var sshConfiguration: SSHConfiguration {
        SSHConfiguration(host: host, username: username)
    }

    func save(defaults: UserDefaults = .standard) {
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        projectPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        teacherProjectPath = teacherProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(host, forKey: Key.host)
        defaults.set(username, forKey: Key.username)
        defaults.set(projectPath, forKey: Key.projectPath)
        defaults.set(teacherProjectPath, forKey: Key.teacherProjectPath)
        defaults.set(language.rawValue, forKey: Key.language)
    }
}
