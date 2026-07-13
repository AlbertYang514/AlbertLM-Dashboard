import SwiftUI

struct CheckpointsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Checkpoints", subtitle: "Checkpoint files reported by albertlmctl checkpoints.")
                Button("Refresh") { Task { await appModel.refreshCheckpoints() } }
            }

            Table(appModel.checkpoints) {
                TableColumn("Checkpoint", value: \.name)
                TableColumn("Date", value: \.date)
                TableColumn("Size", value: \.size)
            }
            .overlay {
                if appModel.checkpoints.isEmpty {
                    ContentUnavailableView("No Checkpoints", systemImage: "externaldrive", description: Text("The controller returned no checkpoint files."))
                }
            }
        }
        .padding(24)
        .navigationTitle("Checkpoints")
    }
}
