import SwiftUI

struct ExperimentsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private var experiment: ExperimentStatus { appModel.experimentStatus }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Experiments", subtitle: "Manage the current AlbertLM training experiment.")

                GroupBox("Current Experiment") {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text(experiment.name).font(.title2.weight(.semibold))
                            Spacer()
                            StatusPill(text: localizedStatusKey(experiment.status), color: statusColor)
                        }

                        Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 14) {
                            experimentRow("Model", experiment.model)
                            experimentRow("Dataset", experiment.dataset)
                            localizedStatusRow("Training status", experiment.status)
                            experimentRow("Current step", experiment.step.formatted())
                            experimentRow("Loss", String(format: "%.8f", experiment.loss))
                            experimentRow("Checkpoint", displayedCheckpoint)
                        }

                        Divider()
                        HStack {
                            Button {
                                Task { await appModel.startTraining() }
                            } label: {
                                Label("Start Training", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            Button(role: .destructive) {
                                Task { await appModel.stopTraining() }
                            } label: {
                                Label("Stop Training", systemImage: "stop.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            if appModel.isTrainingActionRunning { ProgressView().controlSize(.small) }
                            Spacer()
                            Button("Refresh") { Task { await appModel.refreshExperiment() } }
                        }
                        .disabled(appModel.isTrainingActionRunning)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
        .navigationTitle("Experiments")
        .task { await appModel.refreshExperiment() }
    }

    private var displayedCheckpoint: String {
        if !experiment.checkpoint.isEmpty { return experiment.checkpoint }
        if !appModel.trainingStatus.checkpoint.isEmpty { return appModel.trainingStatus.checkpoint }
        return "—"
    }

    private var statusColor: Color {
        let value = experiment.status.lowercased()
        if value.contains("train") || value.contains("run") { return .green }
        if value.contains("error") || value.contains("fail") { return .red }
        return .secondary
    }

    @ViewBuilder
    private func experimentRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text(value).fontDesign(.monospaced).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func localizedStatusRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text(localizedStatusKey(value)).fontDesign(.monospaced)
        }
    }
}
