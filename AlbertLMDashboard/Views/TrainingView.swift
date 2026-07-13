import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Training", subtitle: "Control the AlbertLM training session through the remote node controller.")

                HStack(spacing: 12) {
                    Button {
                        Task { await appModel.startTraining() }
                    } label: {
                        Label("Start Training", systemImage: "play.fill")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive) {
                        Task { await appModel.stopTraining() }
                    } label: {
                        Label("Stop Training", systemImage: "stop.fill")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)

                    if appModel.isTrainingActionRunning { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Refresh Status") { Task { await appModel.refreshStatus() } }
                }
                .disabled(appModel.isTrainingActionRunning)

                GroupBox("Current Status") {
                    Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 14) {
                        localizedStatusRow("Status", appModel.trainingStatus.status)
                        statusRow("Step", appModel.trainingStatus.step.formatted())
                        statusRow("Loss", String(format: "%.8f", appModel.trainingStatus.loss))
                        statusRow("Checkpoint", appModel.trainingStatus.checkpoint.isEmpty ? "—" : appModel.trainingStatus.checkpoint)
                        statusRow("GPU", appModel.trainingStatus.gpu.isEmpty ? "—" : appModel.trainingStatus.gpu)
                        statusRow("Updated", appModel.trainingStatus.time.isEmpty ? "—" : appModel.trainingStatus.time)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !appModel.tmuxOutput.isEmpty {
                    GroupBox("Controller Response") {
                        Text(appModel.tmuxOutput)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Training")
    }

    @ViewBuilder
    private func statusRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(value).fontDesign(.monospaced).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func localizedStatusRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(localizedStatusKey(value)).fontDesign(.monospaced)
        }
    }
}
