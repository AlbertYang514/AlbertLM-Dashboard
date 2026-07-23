import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selection: SidebarItem? = .dashboard
    @Published private(set) var connectionState: ConnectionState = .unknown
    @Published private(set) var lastConnectedAt: Date?
    @Published private(set) var trainingStatus: TrainingStatus = .empty
    @Published private(set) var gpus: [GPUStatus] = []
    @Published private(set) var systemStatus: SystemStatus = .empty
    @Published private(set) var workstationStatus: WorkstationStatus = .empty
    @Published private(set) var trainingMetrics: [TrainingMetric] = []
    @Published private(set) var latestEvaluation: EvaluationLatest?
    @Published private(set) var evaluationMetrics: [EvaluationMetric] = []
    @Published private(set) var generatedSampleBatches: [GeneratedSampleBatch] = []
    @Published private(set) var hardwareHistory: [SystemHistorySample] = []
    @Published private(set) var checkpointIndex: CheckpointIndex = .empty
    @Published private(set) var checkpointLoadError: String?
    @Published private(set) var evaluationLoadError: String?
    @Published private(set) var samplesLoadError: String?
    @Published private(set) var experimentStatus: ExperimentStatus = .empty
    @Published private(set) var datasets: [DatasetFile] = []
    @Published private(set) var teacherStatuses: [TeacherKind: TeacherStatus] = Dictionary(
        uniqueKeysWithValues: TeacherKind.allCases.map { ($0, .placeholder(for: $0)) }
    )
    @Published private(set) var teacherErrors: [TeacherKind: String] = [:]
    @Published private(set) var busyTeachers: Set<TeacherKind> = []
    @Published private(set) var trainingLogOutput = ""
    @Published private(set) var trainingLogPage = 0
    @Published private(set) var trainingLogPageCount = 0
    @Published private(set) var trainingLogRevision = 0
    @Published private(set) var trainingLogScrollsToLatest = false
    @Published private(set) var controllerResponse = ""
    @Published private(set) var isRefreshing = false
    @Published private(set) var isTrainingRefreshing = false
    @Published private(set) var isRefreshingTrainingLog = false
    @Published private(set) var isTrainingActionRunning = false
    @Published private(set) var isGeneratingDataset = false
    @Published private(set) var datasetGenerationResponse = ""
    @Published var presentedError: String?

    let settings: SettingsStore
    private let sshService: SSHService
    private let nodeService: AlbertLMNodeService
    private let teacherService: TeacherService

    init(settings: SettingsStore) {
        self.settings = settings
        let ssh = SSHService(configuration: settings.sshConfiguration)
        sshService = ssh
        nodeService = AlbertLMNodeService(ssh: ssh, projectPath: settings.projectPath)
        teacherService = TeacherService(ssh: ssh, projectPath: settings.teacherProjectPath)
    }

    var primaryGPU: GPUStatus? { gpus.first }

    func applySettings() async {
        settings.save()
        await sshService.update(configuration: settings.sshConfiguration)
        await nodeService.update(projectPath: settings.projectPath)
        await teacherService.update(projectPath: settings.teacherProjectPath)
        await refreshAll()
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        connectionState = .connecting
        presentedError = nil
        defer { isRefreshing = false }

        async let statusResult = capture { try await nodeService.status() }
        async let gpuResult = capture { try await nodeService.gpu() }
        async let systemResult = capture { try await nodeService.hardwareStatus() }
        async let checkpointResult = capture { try await nodeService.checkpoints() }
        let results = await (statusResult, gpuResult, systemResult, checkpointResult)

        switch results.0 {
        case .success(let value):
            trainingStatus = value
            connectionState = .online
            lastConnectedAt = Date()
        case .failure(let error):
            connectionState = .offline(error.localizedDescription)
            presentedError = error.localizedDescription
            return
        }

        var supplementalErrors: [String] = []
        switch results.1 {
        case .success(let value): gpus = value
        case .failure(let error): supplementalErrors.append(error.localizedDescription)
        }
        switch results.2 {
        case .success(let value): workstationStatus = value
        case .failure(let error): supplementalErrors.append(error.localizedDescription)
        }
        switch results.3 {
        case .success(let value): applyCheckpointIndex(value)
        case .failure:
            checkpointLoadError = "Checkpoint index could not be loaded."
        }
        if !supplementalErrors.isEmpty {
            presentedError = supplementalErrors.joined(separator: "\n")
        }
    }

    func refreshStatus() async {
        await performNodeRead { [self] in
            trainingStatus = try await nodeService.status()
        }
    }

    func refreshTrainingData() async {
        guard !isTrainingRefreshing else { return }
        isTrainingRefreshing = true
        defer { isTrainingRefreshing = false }

        async let statusResult = capture { try await nodeService.status() }
        async let metricsResult = capture { try await nodeService.trainingMetrics() }
        async let checkpointResult = capture { try await nodeService.checkpoints() }
        async let evaluationLatestResult = capture { try await nodeService.evaluationLatest() }
        async let evaluationMetricsResult = capture { try await nodeService.evaluationMetrics() }
        async let samplesResult = capture { try await nodeService.generatedSamples() }
        let results = await (statusResult, metricsResult, checkpointResult, evaluationLatestResult, evaluationMetricsResult, samplesResult)
        applyNodeResults([
            results.0.map { [self] value in trainingStatus = value },
            results.1.map { [self] value in trainingMetrics = value }
        ])
        switch results.2 {
        case .success(let value): applyCheckpointIndex(value)
        case .failure: checkpointLoadError = "Checkpoint index could not be loaded."
        }
        switch results.3 {
        case .success(let value):
            if let value { latestEvaluation = value }
            evaluationLoadError = nil
        case .failure:
            evaluationLoadError = "Evaluation data could not be loaded."
        }
        switch results.4 {
        case .success(let value):
            if !value.isEmpty || evaluationMetrics.isEmpty { evaluationMetrics = value }
            evaluationLoadError = nil
        case .failure:
            evaluationLoadError = "Evaluation data could not be loaded."
        }
        switch results.5 {
        case .success(let value):
            generatedSampleBatches = value
            samplesLoadError = nil
        case .failure:
            samplesLoadError = "Generated samples could not be loaded."
        }
    }

    func refreshGPU() async {
        await performNodeRead { [self] in
            gpus = try await nodeService.gpu()
        }
    }

    func refreshSystem() async {
        await performNodeRead { [self] in
            workstationStatus = try await nodeService.hardwareStatus()
        }
    }

    func refreshHardwareData() async {
        async let statusResult = capture { try await nodeService.hardwareStatus() }
        async let historyResult = capture { try await nodeService.systemHistory() }
        let results = await (statusResult, historyResult)
        applyNodeResults([
            results.0.map { [self] value in workstationStatus = value },
            results.1.map { [self] value in hardwareHistory = value }
        ])
    }

    func refreshCheckpoints() async {
        do {
            applyCheckpointIndex(try await nodeService.checkpoints())
            connectionState = .online
            lastConnectedAt = Date()
        } catch {
            checkpointLoadError = "Checkpoint index could not be loaded."
        }
    }

    func refreshExperiment() async {
        await performNodeRead { [self] in
            experimentStatus = try await nodeService.experimentStatus()
        }
    }

    func refreshDatasets() async {
        await performNodeRead { [self] in
            datasets = try await nodeService.datasets()
        }
    }

    func refreshTeachers() async {
        let teachers = Set(TeacherKind.allCases)
        guard busyTeachers.isDisjoint(with: teachers) else { return }
        busyTeachers.formUnion(teachers)
        defer { busyTeachers.subtract(teachers) }
        await withTaskGroup(of: (TeacherKind, Result<TeacherStatus, Error>).self) { group in
            for teacher in TeacherKind.allCases {
                group.addTask { [teacherService] in
                    do { return (teacher, .success(try await teacherService.status(for: teacher))) }
                    catch { return (teacher, .failure(error)) }
                }
            }
            for await (teacher, result) in group {
                applyTeacherResult(result, for: teacher)
            }
        }
    }

    func refreshTeacher(_ teacher: TeacherKind) async {
        guard !busyTeachers.contains(teacher) else { return }
        busyTeachers.insert(teacher)
        defer { busyTeachers.remove(teacher) }
        do {
            applyTeacherResult(.success(try await teacherService.status(for: teacher)), for: teacher)
            connectionState = .online
            lastConnectedAt = Date()
        } catch {
            applyTeacherResult(.failure(error), for: teacher)
        }
    }

    func startTeacher(_ teacher: TeacherKind) async {
        await runTeacherAction(.start, for: teacher)
    }

    func stopTeacher(_ teacher: TeacherKind) async {
        await runTeacherAction(.stop, for: teacher)
    }

    @discardableResult
    func generateDataset(teacher: TeacherKind, input: String, output: String) async -> Bool {
        guard !isGeneratingDataset else { return false }
        isGeneratingDataset = true
        datasetGenerationResponse = ""
        defer { isGeneratingDataset = false }
        do {
            let response = try await teacherService.generateDataset(teacher: teacher, input: input, output: output)
            datasetGenerationResponse = response.isEmpty ? "Dataset generation request completed." : response
            connectionState = .online
            lastConnectedAt = Date()
            return true
        } catch {
            presentedError = error.localizedDescription
            return false
        }
    }

    func clearDatasetGenerationResponse() {
        datasetGenerationResponse = ""
    }

    func refreshTrainingLog(page: Int? = nil) async {
        guard !isRefreshingTrainingLog else { return }
        isRefreshingTrainingLog = true
        defer { isRefreshingTrainingLog = false }
        do {
            let result = try await nodeService.trainingLogPage(page)
            trainingLogOutput = result.content
            trainingLogPageCount = result.totalLines == 0 ? 0 : (result.totalLines + AlbertLMNodeService.trainingLogLinesPerPage - 1) / AlbertLMNodeService.trainingLogLinesPerPage
            trainingLogPage = result.page
            trainingLogScrollsToLatest = page == nil
            trainingLogRevision += 1
            connectionState = .online
            lastConnectedAt = Date()
        } catch {
            presentedError = error.localizedDescription
            connectionState = .offline(error.localizedDescription)
        }
    }

    func startTraining() async {
        await runTrainingAction(.start)
    }

    func stopTraining() async {
        await runTrainingAction(.stop)
    }

    private func runTrainingAction(_ command: NodeCommand) async {
        guard !isTrainingActionRunning else { return }
        isTrainingActionRunning = true
        defer { isTrainingActionRunning = false }
        do {
            let response = try await nodeService.execute(command)
            controllerResponse = response
            connectionState = .online
            lastConnectedAt = Date()
            try? await Task.sleep(for: .milliseconds(500))
            trainingStatus = try await nodeService.status()
            trainingMetrics = (try? await nodeService.trainingMetrics()) ?? trainingMetrics
            if let latest = try? await nodeService.evaluationLatest() {
                latestEvaluation = latest
            }
            if let status = try? await nodeService.experimentStatus() {
                experimentStatus = status
            }
        } catch {
            presentedError = error.localizedDescription
            connectionState = .offline(error.localizedDescription)
        }
    }

    private func runTeacherAction(_ action: TeacherAction, for teacher: TeacherKind) async {
        guard !busyTeachers.contains(teacher) else { return }
        busyTeachers.insert(teacher)
        defer { busyTeachers.remove(teacher) }
        do {
            _ = try await teacherService.execute(teacher, action: action)
            try? await Task.sleep(for: .milliseconds(500))
            applyTeacherResult(.success(try await teacherService.status(for: teacher)), for: teacher)
            connectionState = .online
            lastConnectedAt = Date()
        } catch {
            applyTeacherResult(.failure(error), for: teacher)
            presentedError = error.localizedDescription
        }
    }

    private func applyTeacherResult(_ result: Result<TeacherStatus, Error>, for teacher: TeacherKind) {
        switch result {
        case .success(let status):
            teacherStatuses[teacher] = status
            teacherErrors.removeValue(forKey: teacher)
        case .failure(let error):
            teacherStatuses[teacher] = TeacherStatus(
                kind: teacher,
                state: .error,
                modelName: teacherStatuses[teacher]?.modelName ?? teacher.displayName,
                port: teacherStatuses[teacher]?.port ?? "—",
                gpuUsage: teacherStatuses[teacher]?.gpuUsage ?? "—",
                lastUpdate: teacherStatuses[teacher]?.lastUpdate ?? "—",
                message: error.localizedDescription
            )
            teacherErrors[teacher] = error.localizedDescription
        }
    }

    private func applyCheckpointIndex(_ value: CheckpointIndex?) {
        guard let value else {
            checkpointLoadError = "Checkpoint index is unavailable."
            return
        }
        checkpointIndex = value
        checkpointLoadError = nil
    }

    private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }

    private func applyNodeResults(_ results: [Result<Void, Error>]) {
        let errors = results.compactMap { result -> String? in
            if case .failure(let error) = result { return error.localizedDescription }
            return nil
        }
        if errors.count == results.count {
            let message = errors.joined(separator: "\n")
            presentedError = message
            connectionState = .offline(message)
        } else {
            connectionState = .online
            lastConnectedAt = Date()
            if !errors.isEmpty { presentedError = errors.joined(separator: "\n") }
        }
    }

    private func performNodeRead(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            connectionState = .online
            lastConnectedAt = Date()
        } catch {
            presentedError = error.localizedDescription
            connectionState = .offline(error.localizedDescription)
        }
    }
}
