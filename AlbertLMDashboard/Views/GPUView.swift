import SwiftUI

struct GPUView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(title: "GPU", subtitle: "Accelerator telemetry reported by albertlmctl gpu.")
                    Button("Refresh") { Task { await appModel.refreshGPU() } }
                }

                if appModel.gpus.isEmpty {
                    ContentUnavailableView("No GPU Data", systemImage: "cpu", description: Text("Connect to the remote node to load telemetry."))
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    ForEach(appModel.gpus) { gpu in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(gpu.name).font(.title2.weight(.semibold))
                                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                                    gpuRow("GPU utilization", gpu.utilizationText)
                                    gpuRow("Temperature", gpu.temperatureText)
                                    gpuRow("Power", gpu.powerText)
                                    gpuRow("Memory", gpu.memoryText)
                                }
                                ProgressView(value: gpu.memoryFraction) {
                                    Text("VRAM").font(.caption)
                                }
                                .tint(.blue)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("GPU")
    }

    @ViewBuilder
    private func gpuRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
            Text(value).font(.body.monospacedDigit())
        }
    }
}
