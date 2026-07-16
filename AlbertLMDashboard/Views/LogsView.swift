import SwiftUI
import AppKit

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

            ZStack(alignment: .topLeading) {
                LogTextView(
                    text: appModel.trainingLogOutput,
                    revision: appModel.trainingLogRevision
                )

                if appModel.isRefreshingTrainingLog {
                    ProgressView("Loading log page…")
                        .padding(14)
                } else if appModel.trainingLogOutput.isEmpty {
                    Text("Run View Logs to read train.log from the beginning.")
                        .foregroundStyle(.secondary)
                        .padding(14)
                }
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
                    Text("Page \(appModel.trainingLogPage + 1) / \(appModel.trainingLogPageCount) · 2,500 lines per page")
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

private struct LogTextView: NSViewRepresentable {
    let text: String
    let revision: Int

    final class Coordinator {
        var displayedRevision = -1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.displayedRevision != revision,
              let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.displayedRevision = revision
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor

        if let textContainer = textView.textContainer,
           let layoutManager = textView.layoutManager {
            layoutManager.ensureLayout(for: textContainer)
            let usedSize = layoutManager.usedRect(for: textContainer).size
            textView.setFrameSize(NSSize(
                width: max(scrollView.contentSize.width, ceil(usedSize.width) + 28),
                height: max(scrollView.contentSize.height, ceil(usedSize.height) + 28)
            ))
        }

        DispatchQueue.main.async {
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
