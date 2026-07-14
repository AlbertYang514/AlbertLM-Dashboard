import SwiftUI

struct CheckpointsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(title: "Checkpoints", subtitle: "Checkpoint index loaded from the remote training logs.")
                    Button("Refresh") { Task { await appModel.refreshCheckpoints() } }
                }

                if let latest = appModel.checkpointIndex.latest {
                    latestCheckpointCard(latest)
                }

                Text("All Checkpoints")
                    .font(.title2.bold())

                if let error = appModel.checkpointLoadError, appModel.checkpointIndex.checkpoints.isEmpty {
                    ContentUnavailableView(
                        "Checkpoints unavailable",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(LocalizedStringKey(error))
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else if appModel.checkpointIndex.checkpoints.isEmpty {
                    ContentUnavailableView("No checkpoints found", systemImage: "externaldrive")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(appModel.checkpointIndex.checkpoints) { checkpoint in
                            checkpointRow(checkpoint)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Checkpoints")
        .task { await appModel.refreshCheckpoints() }
    }

    private func latestCheckpointCard(_ checkpoint: CheckpointRecord) -> some View {
        DashboardCard(title: "Latest Checkpoint", icon: "externaldrive.fill.badge.checkmark") {
            MetricRow(label: "Step", value: checkpoint.step.formatted())
            MetricRow(label: "Tokens", value: compactCount(checkpoint.tokens))
            MetricRow(label: "Modified At", value: checkpoint.modifiedAt.isEmpty ? "—" : checkpoint.modifiedAt)
            MetricRow(label: "Model State Size", value: binaryByteCount(checkpoint.modelStateBytes))
            VStack(alignment: .leading, spacing: 4) {
                Text("Checkpoint Path").foregroundStyle(.secondary)
                Text(checkpoint.path.isEmpty ? "—" : checkpoint.path)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func checkpointRow(_ checkpoint: CheckpointRecord) -> some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 8) {
                GridRow {
                    checkpointValue("Step", checkpoint.step.formatted())
                    checkpointValue("Tokens", compactCount(checkpoint.tokens))
                    checkpointValue("Model State Size", binaryByteCount(checkpoint.modelStateBytes))
                }
                GridRow {
                    Text("Modified At").foregroundStyle(.secondary)
                    Text(checkpoint.modifiedAt.isEmpty ? "—" : checkpoint.modifiedAt)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                        .gridCellColumns(5)
                }
                GridRow {
                    Text("Checkpoint Path").foregroundStyle(.secondary)
                    Text(checkpoint.path.isEmpty ? "—" : checkpoint.path)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                        .gridCellColumns(5)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("\(String(localized: "Step", locale: appModel.settings.language.locale)) \(checkpoint.step.formatted())")
        }
    }

    private func checkpointValue(_ title: LocalizedStringKey, _ value: String) -> some View {
        Group {
            Text(title).foregroundStyle(.secondary)
            Text(value).fontDesign(.monospaced).textSelection(.enabled)
        }
    }
}
