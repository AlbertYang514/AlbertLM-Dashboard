import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "AlbertLM Dashboard", subtitle: "Ludan No. 2 · Remote AI Training Node")

                HStack(alignment: .top, spacing: 16) {
                    serverCard
                    trainingCard
                }

                cpuCard

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    gpuCard
                    memoryCard
                    swapCard
                    diskCard
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
            let gpu = appModel.workstationStatus.gpu
            Text(display(gpu?.model)).font(.title3.weight(.semibold)).lineLimit(2)
            MetricRow(label: "VRAM used", value: display(gpu?.memoryUsed))
            MetricRow(label: "VRAM total", value: display(gpu?.memoryTotal))
            MetricRow(label: "GPU utilization", value: display(gpu?.utilization))
            MetricRow(label: "GPU temperature", value: display(gpu?.temperature))
            MetricRow(label: "Power draw", value: display(gpu?.power))
        }
    }

    private var trainingCard: some View {
        DashboardCard(title: "Training Status", icon: "waveform.path.ecg") {
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

    private var cpuCard: some View {
        DashboardCard(title: "CPU", icon: "cpu.fill") {
            let cpu = appModel.workstationStatus.cpu
            Text(display(cpu?.model)).font(.title3.weight(.semibold)).lineLimit(2)
            MetricRow(label: "Cores / Threads", value: "\(display(cpu?.cores)) / \(display(cpu?.threads))")
            MetricRow(label: "Current frequency", value: display(cpu?.frequency))
            MetricRow(label: "CPU usage", value: display(cpu?.usage))
            MetricRow(label: "CPU temperature", value: display(cpu?.temperature))
            if let cores = cpu?.perCore, !cores.isEmpty {
                Text("Per-core load").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 6)], spacing: 6) {
                    ForEach(cores) { core in
                        VStack(spacing: 2) {
                            Text("#\(core.core)").foregroundStyle(.secondary)
                            Text(core.usage).monospacedDigit()
                        }
                        .font(.caption2)
                        .padding(5)
                        .frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
    }

    private var memoryCard: some View {
        DashboardCard(title: "Memory", icon: "memorychip") {
            let memory = appModel.workstationStatus.memory
            MetricRow(label: "Total RAM", value: display(memory?.total))
            MetricRow(label: "Used RAM", value: display(memory?.used))
            MetricRow(label: "Available RAM", value: display(memory?.available))
            MetricRow(label: "Memory usage", value: display(memory?.usage))
        }
    }

    private var swapCard: some View {
        DashboardCard(title: "Swap", icon: "arrow.left.arrow.right.square") {
            let swap = appModel.workstationStatus.memory?.swap
            MetricRow(label: "Total swap", value: display(swap?.total))
            MetricRow(label: "Used swap", value: display(swap?.used))
            MetricRow(label: "Remaining swap", value: display(swap?.remaining))
        }
    }

    private var diskCard: some View {
        DashboardCard(title: "Disk", icon: "internaldrive") {
            let disk = appModel.workstationStatus.disk
            diskRows(title: "System disk", volume: disk?.system)
            Divider()
            diskRows(title: "Data disk", volume: disk?.data)
            Divider()
            Text("SSD temperatures").font(.caption).foregroundStyle(.secondary)
            if let temperatures = disk?.ssdTemperatures, !temperatures.isEmpty {
                ForEach(temperatures) { sensor in
                    MetricRow(label: LocalizedStringKey(sensor.device), value: sensor.temperature)
                }
            } else {
                Text("N/A").foregroundStyle(.secondary)
            }
        }
    }

    private var systemCard: some View {
        DashboardCard(title: "System", icon: "gauge.with.dots.needle.67percent") {
            let system = appModel.workstationStatus.system
            MetricRow(label: "Ubuntu", value: display(system?.ubuntu))
            MetricRow(label: "Kernel", value: display(system?.kernel))
            MetricRow(label: "CUDA", value: display(system?.cuda))
            MetricRow(label: "NVIDIA driver", value: display(system?.nvidiaDriver))
            MetricRow(label: "Uptime", value: display(system?.uptime))
            Button("Refresh System") {
                Task { await appModel.refreshSystem() }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func diskRows(title: LocalizedStringKey, volume: DiskVolumeStatus?) -> some View {
        Text(title).font(.subheadline.weight(.semibold))
        MetricRow(label: "Used / Total", value: "\(display(volume?.used)) / \(display(volume?.total)) (\(display(volume?.usage)))")
        MetricRow(label: "Available", value: display(volume?.available))
    }

    private func display(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return String(localized: "N/A", locale: appModel.settings.language.locale)
        }
        return value
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
