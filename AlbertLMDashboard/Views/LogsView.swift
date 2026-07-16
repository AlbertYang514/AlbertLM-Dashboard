import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Logs", subtitle: "Complete training output read from the remote log file.")
                Button {
                    Task { await appModel.refreshTrainingLog() }
                } label: {
                    Label("View Logs", systemImage: "arrow.clockwise")
                }
                .disabled(appModel.isRefreshingTrainingLog)
            }

            ScrollView([.vertical, .horizontal]) {
                Group {
                    if appModel.isRefreshingTrainingLog {
                        ProgressView("Loading log page…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if appModel.trainingLogOutput.isEmpty {
                        Text("Run View Logs to read train.log from the beginning.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: appModel.trainingLogOutput)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary) }

            HStack(spacing: 12) {
                Button("Previous") {
                    Task { await appModel.refreshTrainingLog(page: appModel.trainingLogPage - 1) }
                }
                .disabled(appModel.trainingLogPage == 0 || appModel.isRefreshingTrainingLog)

                Spacer()

                if appModel.trainingLogPageCount > 0 {
                    Text("Page \(appModel.trainingLogPage + 1) of \(appModel.trainingLogPageCount) · 8,000 lines per page")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Next") {
                    Task { await appModel.refreshTrainingLog(page: appModel.trainingLogPage + 1) }
                }
                .disabled(appModel.trainingLogPage + 1 >= appModel.trainingLogPageCount || appModel.isRefreshingTrainingLog)
            }
        }
        .padding(24)
        .navigationTitle("Logs")
    }
}
