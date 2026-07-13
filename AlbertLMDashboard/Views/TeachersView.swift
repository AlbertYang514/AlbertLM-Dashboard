import SwiftUI

struct TeachersView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var datasetTeacher: TeacherKind?

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(title: "AI Teachers", subtitle: "Manage inference teachers through teacherctl.sh.")
                    Button {
                        Task { await appModel.refreshTeachers() }
                    } label: {
                        Label("Refresh All", systemImage: "arrow.clockwise")
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(TeacherKind.allCases) { teacher in
                        TeacherCard(teacher: teacher) {
                            datasetTeacher = teacher
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Teachers")
        .task { await appModel.refreshTeachers() }
        .sheet(item: $datasetTeacher) { teacher in
            DatasetGenerationSheet(teacher: teacher)
                .environmentObject(appModel)
        }
    }
}

private struct TeacherCard: View {
    @EnvironmentObject private var appModel: AppViewModel
    let teacher: TeacherKind
    let onGenerateDataset: () -> Void

    private var status: TeacherStatus {
        appModel.teacherStatuses[teacher] ?? .placeholder(for: teacher)
    }

    private var isBusy: Bool { appModel.busyTeachers.contains(teacher) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(teacher.displayName).font(.title2.weight(.semibold))
                    Text(status.modelName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: localizedStatusKey(status.state.rawValue), color: stateColor)
            }

            Divider()
            MetricRow(label: "Port", value: status.port)
            MetricRow(label: "GPU usage", value: status.gpuUsage)
            MetricRow(label: "Last update", value: status.lastUpdate)

            if let error = appModel.teacherErrors[teacher] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
            HStack {
                Button("Start") { Task { await appModel.startTeacher(teacher) } }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(status.state == .running || isBusy)
                Button("Stop", role: .destructive) { Task { await appModel.stopTeacher(teacher) } }
                    .disabled(status.state == .stopped || isBusy)
                Spacer()
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Button { Task { await appModel.refreshTeacher(teacher) } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh \(teacher.displayName)")
                }
            }
            Button {
                onGenerateDataset()
            } label: {
                Label("Generate Dataset", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isBusy)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.quaternary) }
    }

    private var stateColor: Color {
        switch status.state {
        case .running: .green
        case .stopped: .secondary
        case .error: .red
        }
    }
}

private struct DatasetGenerationSheet: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let teacher: TeacherKind
    @State private var input = ""
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Generate Dataset", subtitle: "Use \(teacher.displayName) through datagen.sh.")

            Form {
                TextField("Input", text: $input, prompt: Text("Input file or dataset path"))
                TextField("Output", text: $output, prompt: Text("Output dataset path"))
            }
            .formStyle(.grouped)

            if !appModel.datasetGenerationResponse.isEmpty {
                Text(appModel.datasetGenerationResponse)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                if appModel.isGeneratingDataset { ProgressView().controlSize(.small) }
                Button("Generate") {
                    Task { _ = await appModel.generateDataset(teacher: teacher, input: input, output: output) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isGeneratingDataset)
            }
        }
        .padding(24)
        .frame(width: 560, height: 390)
        .onAppear { appModel.clearDatasetGenerationResponse() }
    }
}
