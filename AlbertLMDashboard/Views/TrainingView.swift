import Charts
import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var showTrainLoss = true
    @State private var showValidationLoss = true

    private var latestMetric: TrainingMetric? { appModel.trainingMetrics.last }
    private var chartMetrics: [TrainingMetric] {
        appModel.trainingMetrics.suffix(250).filter {
            $0.step >= 0 && $0.trainLoss.isFinite && $0.learningRate.isFinite
        }
    }
    private var validationChartMetrics: [EvaluationMetric] {
        appModel.evaluationMetrics.suffix(250).filter {
            $0.optimizerStep >= 0 && $0.validLoss?.isFinite == true
        }
    }
    private var recentCheckpoint: String {
        appModel.checkpointIndex.latest?.path
            ?? (appModel.trainingStatus.checkpoint.isEmpty ? "—" : appModel.trainingStatus.checkpoint)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Training", subtitle: "Control the AlbertLM training session through the remote node controller.")

                controls
                statusPanel
                evaluationCards
                if let error = appModel.evaluationLoadError {
                    Label(LocalizedStringKey(error), systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 16) {
                    lossChart
                    metricChart(title: "Learning Rate Curve", valueLabel: "Learning Rate", color: .blue) { $0.learningRate }
                }

                generatedSamplesSection

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
            Button {
                Task { await appModel.refreshTrainingData() }
            } label: {
                if appModel.isTrainingRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(appModel.isTrainingRefreshing)
        }
        .disabled(appModel.isTrainingActionRunning)
    }

    private var statusPanel: some View {
        GroupBox("Training Metrics") {
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 14) {
                localizedStatusRow("Status", appModel.trainingStatus.status)
                statusRow("Current step", (latestMetric?.step ?? appModel.trainingStatus.step).formatted())
                statusRow("Loss", finiteDecimal(latestMetric?.trainLoss ?? appModel.trainingStatus.loss, places: 6))
                statusRow("Tokens / second", latestMetric.map { finiteDecimal($0.tokensPerSecond, places: 0) } ?? "—")
                statusRow("Tokens Seen", compactCount(latestMetric?.tokensSeen))
                statusRow("Recent Checkpoint", recentCheckpoint)
                statusRow("Updated", latestMetric?.timestamp.isEmpty == false ? latestMetric?.timestamp ?? "—" : (appModel.trainingStatus.time.isEmpty ? "—" : appModel.trainingStatus.time))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var evaluationCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], alignment: .leading, spacing: 16) {
            DashboardCard(title: "Validation Loss", icon: "checkmark.circle") {
                MetricRow(label: "Validation Loss", value: finiteDecimal(appModel.latestEvaluation?.latestValidLoss, places: 6))
                MetricRow(label: "Evaluation Step", value: appModel.latestEvaluation?.latestValidLossStep?.formatted() ?? "—")
                MetricRow(label: "Evaluation Tokens", value: compactCount(appModel.latestEvaluation?.latestValidEvalTokens))
            }

            DashboardCard(title: "Perplexity", icon: "function") {
                MetricRow(label: "Perplexity", value: finiteDecimal(appModel.latestEvaluation?.latestValidPPL, places: 3))
                MetricRow(label: "Evaluation Step", value: appModel.latestEvaluation?.latestValidPPLStep?.formatted() ?? "—")
                MetricRow(label: "Tokens Seen", value: compactCount(appModel.latestEvaluation?.latestValidPPLTokens))
            }

            DashboardCard(title: "Latest Evaluation", icon: "clock.arrow.circlepath") {
                MetricRow(label: "Evaluation Step", value: appModel.latestEvaluation?.latestValidLossStep?.formatted() ?? "—")
                MetricRow(label: "Tokens Seen", value: compactCount(appModel.latestEvaluation?.latestValidLossTokens))
                MetricRow(label: "Updated", value: appModel.latestEvaluation?.updatedAt ?? "—")
            }

            DashboardCard(title: "Latest Sample", icon: "text.quote") {
                MetricRow(label: "Step", value: appModel.latestEvaluation?.latestSampleStep?.formatted() ?? "—")
                MetricRow(label: "Tokens Seen", value: compactCount(appModel.latestEvaluation?.latestSampleTokens))
                MetricRow(label: "Path", value: appModel.latestEvaluation?.latestSamplePath ?? "—")
            }
        }
    }

    private var lossChart: some View {
        let trainLabel = String(localized: "Train Loss", locale: appModel.settings.language.locale)
        let validationLabel = String(localized: "Validation Loss", locale: appModel.settings.language.locale)
        let hasVisibleData = (showTrainLoss && !chartMetrics.isEmpty) || (showValidationLoss && !validationChartMetrics.isEmpty)

        return GroupBox("Loss Curve") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Toggle("Train Loss", isOn: $showTrainLoss)
                    Toggle("Validation Loss", isOn: $showValidationLoss)
                }
                .toggleStyle(.checkbox)

                if !hasVisibleData {
                    ContentUnavailableView("No Metrics", systemImage: "chart.xyaxis.line", description: Text("Metrics will appear after training starts."))
                        .frame(maxWidth: .infinity, minHeight: 210)
                } else {
                    Chart {
                        if showTrainLoss {
                            ForEach(chartMetrics) { metric in
                                LineMark(
                                    x: .value(String(localized: "Step", locale: appModel.settings.language.locale), metric.step),
                                    y: .value(trainLabel, metric.trainLoss)
                                )
                                .foregroundStyle(by: .value("Series", trainLabel))
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        if showValidationLoss {
                            ForEach(validationChartMetrics) { metric in
                                if let loss = metric.validLoss {
                                    LineMark(
                                        x: .value(String(localized: "Step", locale: appModel.settings.language.locale), metric.optimizerStep),
                                        y: .value(validationLabel, loss)
                                    )
                                    .foregroundStyle(by: .value("Series", validationLabel))
                                    PointMark(
                                        x: .value(String(localized: "Step", locale: appModel.settings.language.locale), metric.optimizerStep),
                                        y: .value(validationLabel, loss)
                                    )
                                    .foregroundStyle(by: .value("Series", validationLabel))
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale([trainLabel: Color.orange, validationLabel: Color.purple])
                    .chartXAxisLabel(String(localized: "Step", locale: appModel.settings.language.locale))
                    .chartLegend(position: .bottom, alignment: .leading)
                    .frame(minHeight: 210)
                    .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
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

    private var generatedSamplesSection: some View {
        GroupBox("Generated Samples") {
            VStack(alignment: .leading, spacing: 14) {
                if let error = appModel.samplesLoadError, appModel.generatedSampleBatches.isEmpty {
                    Label(LocalizedStringKey(error), systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                } else if appModel.generatedSampleBatches.isEmpty {
                    ContentUnavailableView("No generated samples yet", systemImage: "text.quote")
                        .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    ForEach(appModel.generatedSampleBatches.prefix(50)) { batch in
                        sampleBatch(batch)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sampleBatch(_ batch: GeneratedSampleBatch) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    statusRow("Step", batch.optimizerStep.formatted())
                    statusRow("Tokens Seen", compactCount(batch.tokensSeen))
                    statusRow("Timestamp", batch.timestamp.isEmpty ? "—" : batch.timestamp)
                    statusRow("Temperature", finiteDecimal(batch.temperature, places: 2))
                    statusRow("Top P", finiteDecimal(batch.topP, places: 2))
                    statusRow("Elapsed", batch.elapsedSeconds.map { "\(finiteDecimal($0, places: 2)) s" } ?? "—")
                }

                ForEach(Array(batch.samples.enumerated()), id: \.offset) { _, sample in
                    Divider()
                    Text("Prompt").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(sample.prompt.isEmpty ? "—" : sample.prompt)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Completion").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ScrollView {
                        Text(sample.completion.isEmpty ? "—" : sample.completion)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                    HStack(spacing: 24) {
                        Text("\(String(localized: "Prompt Tokens", locale: appModel.settings.language.locale)): \(sample.promptTokens?.formatted() ?? "—")")
                        Text("\(String(localized: "Generated Tokens", locale: appModel.settings.language.locale)): \(sample.generatedTokens?.formatted() ?? "—")")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text("\(String(localized: "Step", locale: appModel.settings.language.locale)) \(batch.optimizerStep.formatted())")
        }
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
