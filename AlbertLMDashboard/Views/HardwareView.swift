import SwiftUI

struct HardwareView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(title: "Hardware", subtitle: "Workstation telemetry collected through the remote controller.")
                    Button("Refresh") { Task { await appModel.refreshHardwareData() } }
                }

                if let timestamp = appModel.hardwareHistory.last?.timestamp, !timestamp.isEmpty {
                    MetricRow(label: "Last system sample", value: timestamp)
                }

                cpuCard

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    gpuCard
                    memoryCard
                    swapCard
                    ssdCard
                }
            }
            .padding(24)
        }
        .navigationTitle("Hardware")
        .task { await appModel.refreshHardwareData() }
    }

    private var cpuCard: some View {
        DashboardCard(title: "CPU", icon: "cpu.fill") {
            let cpu = appModel.workstationStatus.cpu
            Text(display(cpu?.model)).font(.headline)
            MetricRow(label: "Cores / Threads", value: "\(display(cpu?.cores)) / \(display(cpu?.threads))")
            MetricRow(label: "Current frequency", value: display(cpu?.frequency))
            MetricRow(label: "CPU usage", value: display(cpu?.usage))
            MetricRow(label: "CPU temperature", value: display(cpu?.temperature))
            if let cores = cpu?.perCore, !cores.isEmpty {
                Divider()
                Text("Per-core load").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 6)], spacing: 6) {
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

    private var gpuCard: some View {
        DashboardCard(title: "GPU", icon: "cpu") {
            if appModel.gpus.isEmpty {
                legacyGPUStatus
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(appModel.gpus.prefix(2).enumerated()), id: \.element.id) { index, gpu in
                        compactGPUStatus(gpu, index: index)
                        if index == 0 && appModel.gpus.count > 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var legacyGPUStatus: some View {
        let gpu = appModel.workstationStatus.gpu
        return VStack(alignment: .leading, spacing: 8) {
            Text(display(gpu?.model)).font(.headline).lineLimit(1)
            MetricRow(label: "GPU utilization", value: display(gpu?.utilization))
            MetricRow(label: "VRAM", value: "\(display(gpu?.memoryUsed)) / \(display(gpu?.memoryTotal))")
            MetricRow(label: "GPU temperature", value: display(gpu?.temperature))
            MetricRow(label: "Power draw", value: display(gpu?.power))
        }
    }

    private func compactGPUStatus(_ gpu: GPUStatus, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPU \(index)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(gpu.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .help(gpu.name)
            compactMetric("Utilization", gpu.utilizationText)
            compactMetric("VRAM", gpu.memoryText)
            compactMetric("Temperature", gpu.temperatureText)
            compactMetric("Power", gpu.powerText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactMetric(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)
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

    private var ssdCard: some View {
        DashboardCard(title: "SSD", icon: "internaldrive") {
            let disk = appModel.workstationStatus.disk
            volumeRows("System disk", disk?.system)
            Divider()
            volumeRows("Data disk", disk?.data)
            Divider()
            Text("SSD temperatures").font(.caption).foregroundStyle(.secondary)
            if let temperatures = disk?.ssdTemperatures, !temperatures.isEmpty {
                ForEach(temperatures) { MetricRow(label: LocalizedStringKey($0.device), value: $0.temperature) }
            } else {
                Text("N/A").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func volumeRows(_ title: LocalizedStringKey, _ volume: DiskVolumeStatus?) -> some View {
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
}
