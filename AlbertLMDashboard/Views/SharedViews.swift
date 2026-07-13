import SwiftUI

struct PageHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardCard<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
            content
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

struct MetricRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontDesign(.monospaced).textSelection(.enabled)
        }
    }
}

struct StatusPill: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

func localizedStatusKey(_ rawValue: String) -> LocalizedStringKey {
    let value = rawValue.lowercased()
    if value.contains("train") { return "Training (Status)" }
    if value.contains("run") || value.contains("online") { return "Running" }
    if value.contains("ready") { return "Ready" }
    if value.contains("stop") || value.contains("offline") || value.contains("idle") { return "Stopped" }
    if value.contains("error") || value.contains("fail") { return "Error" }
    return LocalizedStringKey(rawValue)
}

extension GPUStatus {
    var temperatureText: String { temperature.map { String(format: "%.0f °C", $0) } ?? "—" }
    var powerText: String {
        guard let draw = powerDraw else { return "—" }
        return powerLimit.map { String(format: "%.0f / %.0f W", draw, $0) } ?? String(format: "%.0f W", draw)
    }
    var memoryText: String {
        guard let used = memoryUsed, let total = memoryTotal else { return "—" }
        return String(format: "%.0f / %.0f MiB", used, total)
    }
    var utilizationText: String { utilization.map { String(format: "%.0f%%", $0) } ?? "—" }
}

extension TrainingStatus {
    var statusColor: Color {
        switch status.lowercased() {
        case let value where value.contains("run") || value.contains("train"): .green
        case let value where value.contains("error") || value.contains("fail"): .red
        case let value where value.contains("stop") || value.contains("idle"): .secondary
        default: .orange
        }
    }
}
