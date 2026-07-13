import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "AlbertLM Dashboard", subtitle: "Ludan No. 2 · Remote AI Training Node")

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    serverCard
                    gpuCard
                    trainingCard
                    systemCard
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }

    private var serverCard: some View {
        DashboardCard(title: "Server", icon: "server.rack") {
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 10, height: 10)
                Text(connectionStateKey).font(.title2.weight(.semibold))
                Spacer()
            }
            MetricRow(label: "SSH Host", value: appModel.settings.host)
            MetricRow(label: "Last connection", value: appModel.lastConnectedAt?.formatted(date: .abbreviated, time: .standard) ?? String(localized: "Never", locale: appModel.settings.language.locale))
            if case .offline(let message) = appModel.connectionState {
                Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
            }
        }
    }

    private var gpuCard: some View {
        DashboardCard(title: "GPU", icon: "cpu") {
            if let gpu = appModel.primaryGPU {
                Text(gpu.name).font(.title3.weight(.semibold)).lineLimit(2)
                MetricRow(label: "Utilization", value: gpu.utilizationText)
                MetricRow(label: "Temperature", value: gpu.temperatureText)
                MetricRow(label: "Memory", value: gpu.memoryText)
                ProgressView(value: gpu.memoryFraction)
                    .tint(.blue)
            } else {
                ContentUnavailableView("No GPU Data", systemImage: "cpu", description: Text("Refresh the remote node."))
            }
        }
    }

    private var trainingCard: some View {
        DashboardCard(title: "Training", icon: "waveform.path.ecg") {
            HStack {
                StatusPill(text: localizedStatusKey(appModel.trainingStatus.status), color: appModel.trainingStatus.statusColor)
                Spacer()
                HStack(spacing: 4) {
                    Text("Step")
                    Text(appModel.trainingStatus.step.formatted())
                }
                .font(.headline.monospacedDigit())
            }
            MetricRow(label: "Loss", value: String(format: "%.6f", appModel.trainingStatus.loss))
            MetricRow(label: "Checkpoint", value: appModel.trainingStatus.checkpoint.isEmpty ? "—" : appModel.trainingStatus.checkpoint)
            MetricRow(label: "Updated", value: appModel.trainingStatus.time.isEmpty ? "—" : appModel.trainingStatus.time)
        }
    }

    private var systemCard: some View {
        DashboardCard(title: "System", icon: "gauge.with.dots.needle.67percent") {
            MetricRow(label: "CPU load", value: appModel.systemStatus.cpuLoad)
            MetricRow(label: "RAM used", value: appModel.systemStatus.memoryUsed)
            MetricRow(label: "RAM total", value: appModel.systemStatus.memoryTotal)
            MetricRow(label: "Disk used", value: appModel.systemStatus.diskUsed)
            Button("Refresh System") {
                Task { await appModel.refreshSystem() }
            }
            .controlSize(.small)
        }
    }

    private var connectionColor: Color {
        switch appModel.connectionState {
        case .online: .green
        case .offline: .red
        case .connecting: .orange
        case .unknown: .secondary
        }
    }

    private var connectionStateKey: LocalizedStringKey {
        switch appModel.connectionState {
        case .online: "Online"
        case .offline: "Offline"
        case .connecting: "Connecting…"
        case .unknown: "Unknown"
        }
    }
}
