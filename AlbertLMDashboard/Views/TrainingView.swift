import Charts
import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private var latestMetric: TrainingMetric? { appModel.trainingMetrics.last }
    private var chartMetrics: [TrainingMetric] { Array(appModel.trainingMetrics.suffix(250)) }
    private var recentCheckpoint: String {
        appModel.checkpoints.first?.name
            ?? (appModel.trainingStatus.checkpoint.isEmpty ? "—" : appModel.trainingStatus.checkpoint)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Training", subtitle: "Control the AlbertLM training session through the remote node controller.")

                controls
                statusPanel

                HStack(alignment: .top, spacing: 16) {
                    metricChart(title: "Loss Curve", valueLabel: "Loss", color: .orange) { $0.trainLoss }
                    metricChart(title: "Learning Rate Curve", valueLabel: "Learning Rate", color: .blue) { $0.learningRate }
                }

                if !appModel.controllerResponse.isEmpty {
                    GroupBox("Controller Response") {
                        Text(appModel.controllerResponse)
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
        .task { await appModel.refreshTrainingData() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await appModel.startTraining() }
            } label: {
                Label("Start Training", systemImage: "play.fill").frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button(role: .destructive) {
                Task { await appModel.stopTraining() }
            } label: {
                Label("Stop Training", systemImage: "stop.fill").frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)

            if appModel.isTrainingActionRunning { ProgressView().controlSize(.small) }
            Spacer()
            Button("Refresh") { Task { await appModel.refreshTrainingData() } }
        }
        .disabled(appModel.isTrainingActionRunning)
    }

    private var statusPanel: some View {
        GroupBox("Training Metrics") {
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 14) {
                localizedStatusRow("Status", appModel.trainingStatus.status)
                statusRow("Current step", (latestMetric?.step ?? appModel.trainingStatus.step).formatted())
                statusRow("Loss", String(format: "%.6f", latestMetric?.trainLoss ?? appModel.trainingStatus.loss))
                statusRow("Tokens / second", latestMetric.map { String(format: "%.0f", $0.tokensPerSecond) } ?? "—")
                statusRow("Tokens Seen", latestMetric?.tokensSeen.formatted() ?? "—")
                statusRow("Recent Checkpoint", recentCheckpoint)
                statusRow("Updated", latestMetric?.timestamp.isEmpty == false ? latestMetric?.timestamp ?? "—" : (appModel.trainingStatus.time.isEmpty ? "—" : appModel.trainingStatus.time))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricChart(
        title: LocalizedStringKey,
        valueLabel: String.LocalizationValue,
        color: Color,
        value: @escaping (TrainingMetric) -> Double
    ) -> some View {
        GroupBox(title) {
            if chartMetrics.isEmpty {
                ContentUnavailableView("No Metrics", systemImage: "chart.xyaxis.line", description: Text("Metrics will appear after training starts."))
                    .frame(maxWidth: .infinity, minHeight: 210)
            } else {
                Chart(chartMetrics) { metric in
                    LineMark(
                        x: .value(String(localized: "Step", locale: appModel.settings.language.locale), metric.step),
                        y: .value(String(localized: valueLabel, locale: appModel.settings.language.locale), value(metric))
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxisLabel(String(localized: "Step", locale: appModel.settings.language.locale))
                .frame(minHeight: 210)
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statusRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
            Text(value).fontDesign(.monospaced).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func localizedStatusRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
            Text(localizedStatusKey(value)).fontDesign(.monospaced)
        }
    }
}
