import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $appModel.selection) { item in
                Label {
                    Text(LocalizedStringKey(item.rawValue))
                } icon: {
                    Image(systemName: item.icon)
                }
                    .tag(item)
            }
            .navigationTitle("AlbertLM")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            Group {
                switch appModel.selection ?? .dashboard {
                case .dashboard: DashboardView()
                case .training: TrainingView()
                case .teachers: TeachersView()
                case .experiments: ExperimentsView()
                case .datasets: DatasetsView()
                case .hardware: HardwareView()
                case .gpu: GPUView()
                case .logs: LogsView()
                case .checkpoints: CheckpointsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appModel.refreshAll() }
                } label: {
                    if appModel.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(appModel.isRefreshing)
                .help("Refresh remote node status")
            }
        }
        .task {
            if appModel.connectionState == .unknown {
                await appModel.refreshAll()
            }
        }
        .alert("Remote Node Error", isPresented: errorPresented) {
            Button("OK", role: .cancel) { appModel.presentedError = nil }
        } message: {
            Text(appModel.presentedError ?? "Unknown error")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { appModel.presentedError != nil },
            set: { if !$0 { appModel.presentedError = nil } }
        )
    }
}
