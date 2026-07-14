import Foundation
import OSLog

enum NodeCommand: String, Sendable {
    case status
    case gpu
    case start
    case stop
    case tmux
    case system
    case checkpoints
    case datasets
    case metrics
    case systemLog = "system-log"
    case logs
}

enum NodeServiceError: LocalizedError {
    case invalidStatus(String)
    case invalidGPU(String)
    case invalidSystem(String)
    case invalidCheckpoints(String)
    case invalidExperiment(String)
    case invalidDatasets(String)
    case invalidHardwareStatus(String)
    case invalidMetrics(String)
    case invalidSystemHistory(String)
    case invalidEvaluationLatest(String)
    case invalidEvaluationMetrics(String)
    case invalidGeneratedSamples(String)

    var errorDescription: String? {
        switch self {
        case .invalidStatus(let detail): "Invalid status JSON returned by albertlmctl: \(detail)"
        case .invalidGPU(let detail): "Invalid GPU CSV returned by albertlmctl: \(detail)"
        case .invalidSystem(let detail): "Invalid system JSON returned by albertlmctl: \(detail)"
        case .invalidCheckpoints(let detail): "Invalid checkpoints JSON returned by albertlmctl: \(detail)"
        case .invalidExperiment(let detail): "Invalid experiment JSON returned by albertlmctl: \(detail)"
        case .invalidDatasets(let detail): "Invalid datasets JSON returned by albertlmctl: \(detail)"
        case .invalidHardwareStatus(let detail): "Invalid JSON returned by albertlmctl system: \(detail)"
        case .invalidMetrics(let detail): "Invalid training metrics JSONL returned by albertlmctl: \(detail)"
        case .invalidSystemHistory(let detail): "Invalid system history JSONL returned by albertlmctl: \(detail)"
        case .invalidEvaluationLatest(let detail): "Invalid eval_latest.json: \(detail)"
        case .invalidEvaluationMetrics(let detail): "Invalid eval_metrics.jsonl: \(detail)"
        case .invalidGeneratedSamples(let detail): "Invalid samples.jsonl: \(detail)"
        }
    }
}

actor AlbertLMNodeService {
    private static let logger = Logger(subsystem: "com.albertyang.AlbertLMDashboard", category: "NodeService")
    private let ssh: SSHService
    private var projectPath: String

    init(ssh: SSHService, projectPath: String) {
        self.ssh = ssh
        self.projectPath = projectPath
    }

    func update(projectPath: String) {
        self.projectPath = projectPath
    }

    func execute(_ command: NodeCommand) async throws -> String {
        try await execute(arguments: [command.rawValue])
    }

    private func execute(arguments: [String]) async throws -> String {
        let script = shellPath(projectPath) + "/scripts/albertlmctl.sh"
        // GUI apps do not inherit the terminal's LC_* variables. Force the
        // controller's command output to use the stable locale its parsers expect.
        let command = (["env", "LC_ALL=C", "LANG=C", "bash", script] + arguments.map(shellQuote)).joined(separator: " ")
        return try await ssh.run(command: command)
    }

    func status() async throws -> TrainingStatus {
        let text = try await execute(.status)
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidStatus("Not UTF-8") }
        do {
            return try JSONDecoder().decode(TrainingStatus.self, from: data)
        } catch {
            throw NodeServiceError.invalidStatus(error.localizedDescription)
        }
    }

    func gpu() async throws -> [GPUStatus] {
        let text = try await execute(.gpu)
        let rows = parseCSV(text)
        guard !rows.isEmpty else { throw NodeServiceError.invalidGPU("Empty response") }

        let header = rows[0].map { normalizeHeader($0) }
        let hasHeader = header.contains { $0.contains("name") || $0.contains("temperature") || $0.contains("utilization") }
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        let headerIndexes = GPUCSVIndexes(header: hasHeader ? header : [])

        let values = dataRows.compactMap { row -> GPUStatus? in
            guard !row.isEmpty else { return nil }
            // The current /data controller emits six headerless columns:
            // name, temperature, power draw, memory used, memory total, utilization.
            // Seven-column output is also accepted for older controller exports.
            let indexes: GPUCSVIndexes
            if hasHeader {
                indexes = headerIndexes
            } else if row.count == 6 {
                indexes = GPUCSVIndexes(name: 0, temperature: 1, powerDraw: 2, powerLimit: nil, memoryUsed: 3, memoryTotal: 4, utilization: 5)
            } else {
                indexes = GPUCSVIndexes(name: 0, temperature: 1, powerDraw: 2, powerLimit: 3, memoryUsed: 4, memoryTotal: 5, utilization: 6)
            }
            return GPUStatus(
                name: stringValue(row, at: indexes.name) ?? "GPU",
                temperature: numberValue(row, at: indexes.temperature),
                powerDraw: numberValue(row, at: indexes.powerDraw),
                powerLimit: numberValue(row, at: indexes.powerLimit),
                memoryUsed: numberValue(row, at: indexes.memoryUsed),
                memoryTotal: numberValue(row, at: indexes.memoryTotal),
                utilization: numberValue(row, at: indexes.utilization)
            )
        }
        guard !values.isEmpty else { throw NodeServiceError.invalidGPU("No data rows") }
        return values
    }

    func system() async throws -> WorkstationStatus {
        let text = try await execute(.system)
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidSystem("Not UTF-8") }
        do {
            let status = try JSONDecoder().decode(WorkstationStatus.self, from: data)
            logHardwareDiagnostics(status)
            return status
        } catch {
            Self.logger.error("Could not decode albertlmctl system response: \(error.localizedDescription, privacy: .public)")
            throw NodeServiceError.invalidSystem(error.localizedDescription)
        }
    }

    func hardwareStatus() async throws -> WorkstationStatus {
        try await system()
    }

    func checkpoints() async throws -> CheckpointIndex? {
        let text = try await readRemoteFile("logs/checkpoints.json")
        guard !text.isEmpty else { return nil }
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidCheckpoints("Not UTF-8") }
        do {
            let index = try JSONDecoder().decode(CheckpointIndex.self, from: data)
            return CheckpointIndex(
                schemaVersion: index.schemaVersion,
                generatedAt: index.generatedAt,
                latest: index.latest,
                checkpoints: index.checkpoints.sorted { $0.step > $1.step }
            )
        } catch {
            throw NodeServiceError.invalidCheckpoints(error.localizedDescription)
        }
    }

    func evaluationLatest() async throws -> EvaluationLatest? {
        let text = try await readRemoteFile("logs/eval_latest.json")
        guard !text.isEmpty else { return nil }
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidEvaluationLatest("Not UTF-8") }
        do {
            return try JSONDecoder().decode(EvaluationLatest.self, from: data)
        } catch {
            throw NodeServiceError.invalidEvaluationLatest(error.localizedDescription)
        }
    }

    func evaluationMetrics(limit: Int = 2_000) async throws -> [EvaluationMetric] {
        let text = try await readRemoteFile("logs/eval_metrics.jsonl", tailLimit: limit)
        return try decodeJSONLines(text, as: EvaluationMetric.self, error: NodeServiceError.invalidEvaluationMetrics)
            .sorted { $0.optimizerStep < $1.optimizerStep }
    }

    func generatedSamples(limit: Int = 2_000) async throws -> [GeneratedSampleBatch] {
        let text = try await readRemoteFile("logs/samples.jsonl", tailLimit: limit)
        return try decodeJSONLines(text, as: GeneratedSampleBatch.self, error: NodeServiceError.invalidGeneratedSamples)
            .sorted { $0.optimizerStep > $1.optimizerStep }
    }

    func experimentStatus() async throws -> ExperimentStatus {
        let text = try await execute(arguments: ["experiment", "status"])
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidExperiment("Not UTF-8") }
        do {
            return try JSONDecoder().decode(ExperimentStatus.self, from: data)
        } catch {
            throw NodeServiceError.invalidExperiment(error.localizedDescription)
        }
    }

    func datasets() async throws -> [DatasetFile] {
        let text = try await execute(.datasets)
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidDatasets("Not UTF-8") }
        do {
            if let files = try? JSONDecoder().decode([DatasetFile].self, from: data) {
                return files
            }
            return try JSONDecoder().decode(DatasetEnvelope.self, from: data).datasets
        } catch {
            throw NodeServiceError.invalidDatasets(error.localizedDescription)
        }
    }

    func trainingMetrics(limit: Int = 500) async throws -> [TrainingMetric] {
        let text = try await execute(arguments: [NodeCommand.metrics.rawValue, String(clampedLimit(limit))])
        return try decodeJSONLines(text, as: TrainingMetric.self, error: NodeServiceError.invalidMetrics)
    }

    func systemHistory(limit: Int = 120) async throws -> [SystemHistorySample] {
        let text = try await execute(arguments: [NodeCommand.systemLog.rawValue, String(clampedLimit(limit))])
        return try decodeJSONLines(text, as: SystemHistorySample.self, error: NodeServiceError.invalidSystemHistory)
    }

    func trainingLog(limit: Int = 500) async throws -> String {
        try await execute(arguments: [NodeCommand.logs.rawValue, String(clampedLimit(limit))])
    }

    private func clampedLimit(_ value: Int) -> Int {
        min(max(value, 1), 5_000)
    }

    private func decodeJSONLines<T: Decodable>(
        _ text: String,
        as type: T.Type,
        error makeError: (String) -> NodeServiceError
    ) throws -> [T] {
        let lines = text.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return [] }
        let decoder = JSONDecoder()
        var rejectedLines = 0
        let values = lines.enumerated().compactMap { offset, line -> T? in
            guard let data = String(line).data(using: .utf8) else {
                rejectedLines += 1
                Self.logger.error("Rejected non-UTF-8 JSONL record at line \(offset + 1)")
                return nil
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                rejectedLines += 1
                Self.logger.error("Rejected JSONL record at line \(offset + 1): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        if rejectedLines > 0 {
            Self.logger.warning("Decoded \(values.count) JSONL records and rejected \(rejectedLines)")
        }
        if values.isEmpty, rejectedLines > 0 {
            throw makeError("No valid JSON lines; rejected \(rejectedLines) malformed records")
        }
        return values
    }

    private func readRemoteFile(_ relativePath: String, tailLimit: Int? = nil) async throws -> String {
        let path = shellPath(projectPath) + "/" + relativePath
        let readCommand: String
        if let tailLimit {
            readCommand = "tail -n \(clampedLimit(tailLimit)) -- \(path)"
        } else {
            readCommand = "cat -- \(path)"
        }
        let command = "if test -r \(path); then \(readCommand); fi"
        return try await ssh.run(command: command)
    }

    private func logHardwareDiagnostics(_ status: WorkstationStatus) {
        guard let memory = status.memory else {
            Self.logger.error("albertlmctl system response is missing the memory object")
            return
        }

        let missingFields = [
            ("total", memory.total),
            ("used", memory.used),
            ("available", memory.available),
            ("usage", memory.usage)
        ].compactMap { name, value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return name }
            return nil
        }

        if missingFields.isEmpty {
            Self.logger.debug("Decoded system memory total=\(memory.total ?? "N/A", privacy: .public) used=\(memory.used ?? "N/A", privacy: .public) available=\(memory.available ?? "N/A", privacy: .public) usage=\(memory.usage ?? "N/A", privacy: .public)")
        } else {
            Self.logger.error("albertlmctl system memory object is missing fields: \(missingFields.joined(separator: ", "), privacy: .public)")
        }
    }

    private func shellPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("~/") {
            return "$HOME/" + shellQuote(String(trimmed.dropFirst(2)))
        }
        return shellQuote(trimmed)
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func parseCSV(_ text: String) -> [[String]] {
        text.split(whereSeparator: \.isNewline).map { line in
            var fields: [String] = []
            var field = ""
            var quoted = false
            let characters = Array(line)
            var index = 0
            while index < characters.count {
                let character = characters[index]
                if character == "\"" {
                    if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        quoted.toggle()
                    }
                } else if character == ",", !quoted {
                    fields.append(field.trimmingCharacters(in: .whitespaces))
                    field = ""
                } else {
                    field.append(character)
                }
                index += 1
            }
            fields.append(field.trimmingCharacters(in: .whitespaces))
            return fields
        }
    }

    private func normalizeHeader(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func stringValue(_ row: [String], at index: Int?) -> String? {
        guard let index else { return nil }
        guard row.indices.contains(index) else { return nil }
        return row[index].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
    }

    private func numberValue(_ row: [String], at index: Int?) -> Double? {
        guard let value = stringValue(row, at: index) else { return nil }
        let cleaned = value.replacingOccurrences(of: "[^0-9.+-]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
}

private struct DatasetEnvelope: Decodable {
    let datasets: [DatasetFile]

    enum CodingKeys: String, CodingKey { case datasets, items, files }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        datasets = try values.decodeIfPresent([DatasetFile].self, forKey: .datasets)
            ?? values.decodeIfPresent([DatasetFile].self, forKey: .items)
            ?? values.decodeIfPresent([DatasetFile].self, forKey: .files)
            ?? []
    }
}

private struct GPUCSVIndexes {
    var name: Int?
    var temperature: Int?
    var powerDraw: Int?
    var powerLimit: Int?
    var memoryUsed: Int?
    var memoryTotal: Int?
    var utilization: Int?

    init(name: Int?, temperature: Int?, powerDraw: Int?, powerLimit: Int?, memoryUsed: Int?, memoryTotal: Int?, utilization: Int?) {
        self.name = name
        self.temperature = temperature
        self.powerDraw = powerDraw
        self.powerLimit = powerLimit
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.utilization = utilization
    }

    init(header: [String]) {
        name = header.firstIndex { $0 == "name" || $0.contains("gpuname") }
        temperature = header.firstIndex { $0.contains("temperature") || $0.contains("tempgpu") }
        powerDraw = header.firstIndex { $0.contains("powerdraw") }
        powerLimit = header.firstIndex { $0.contains("powerlimit") }
        memoryUsed = header.firstIndex { $0.contains("memoryused") }
        memoryTotal = header.firstIndex { $0.contains("memorytotal") }
        utilization = header.firstIndex { $0.contains("utilization") || $0.contains("utilizationgpu") }
    }
}
