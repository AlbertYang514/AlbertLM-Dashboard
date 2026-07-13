import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Logs", subtitle: "Recent training output read from the remote log file.")
                Button {
                    Task { await appModel.refreshTrainingLog() }
                } label: {
                    Label("View Logs", systemImage: "arrow.clockwise")
                }
            }

            ScrollView([.vertical, .horizontal]) {
                Group {
                    if appModel.trainingLogOutput.isEmpty {
                        Text("Run View Logs to read recent lines from train.log.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(appModel.trainingLogOutput)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary) }
        }
        .padding(24)
        .navigationTitle("Logs")
    }
}
