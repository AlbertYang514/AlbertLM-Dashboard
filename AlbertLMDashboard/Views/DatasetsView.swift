import SwiftUI

struct DatasetsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Datasets", subtitle: "Files reported from ~/AlbertLM/datasets by albertlmctl.")
                Button {
                    Task { await appModel.refreshDatasets() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            Table(appModel.datasets) {
                TableColumn("File Name", value: \.name)
                TableColumn("Size", value: \.size)
                TableColumn("Last Updated", value: \.updated)
            }
            .overlay {
                if appModel.datasets.isEmpty {
                    ContentUnavailableView("No Datasets", systemImage: "cylinder.split.1x2", description: Text("The controller returned no dataset files."))
                }
            }
        }
        .padding(24)
        .navigationTitle("Datasets")
        .task { await appModel.refreshDatasets() }
    }
}
