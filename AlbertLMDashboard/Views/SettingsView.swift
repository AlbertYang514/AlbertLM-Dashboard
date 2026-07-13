import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var appModel: AppViewModel
    @State private var saved = false

    var body: some View {
        Form {
            Section("Remote Training Node") {
                TextField("SSH host", text: $settings.host, prompt: Text("ludan2"))
                TextField("Username (optional)", text: $settings.username)
                TextField("Project path", text: $settings.projectPath, prompt: Text("/data/AlbertLM"))
                TextField("Teacher project path", text: $settings.teacherProjectPath, prompt: Text("/data/AI-Teachers"))
            }

            Section("Language") {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.localizationKey)).tag(language)
                    }
                }
                .pickerStyle(.menu)
                Text("Language changes are saved and remain active after reopening the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("SSH uses /usr/bin/ssh with your system SSH config, existing keys and ssh-agent. Password authentication prompts are disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("Controller:")
                    Text("\(settings.projectPath)/scripts/albertlmctl.sh")
                }
                .font(.caption.monospaced())
                .textSelection(.enabled)
                HStack(spacing: 4) {
                    Text("Teachers:")
                    Text("\(settings.teacherProjectPath)/scripts/teacherctl.sh")
                }
                .font(.caption.monospaced())
                .textSelection(.enabled)
            }

            HStack {
                Button("Save & Test Connection") {
                    saved = false
                    Task {
                        await appModel.applySettings()
                        saved = appModel.connectionState == .online
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(settings.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.teacherProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if appModel.isRefreshing { ProgressView().controlSize(.small) }
                if saved { Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onChange(of: settings.language) {
            settings.save()
        }
    }
}
