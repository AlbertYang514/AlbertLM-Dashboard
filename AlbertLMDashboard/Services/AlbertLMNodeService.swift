import Foundation

enum NodeCommand: String, Sendable {
    case status
    case gpu
    case start
    case stop
    case tmux
    case system
    case checkpoints
    case datasets
}

enum NodeServiceError: LocalizedError {
    case invalidStatus(String)
    case invalidGPU(String)
    case invalidSystem(String)
    case invalidCheckpoints(String)
    case invalidExperiment(String)
    case invalidDatasets(String)

    var errorDescription: String? {
        switch self {
        case .invalidStatus(let detail): "Invalid status JSON returned by albertlmctl: \(detail)"
        case .invalidGPU(let detail): "Invalid GPU CSV returned by albertlmctl: \(detail)"
        case .invalidSystem(let detail): "Invalid system JSON returned by albertlmctl: \(detail)"
        case .invalidCheckpoints(let detail): "Invalid checkpoints JSON returned by albertlmctl: \(detail)"
        case .invalidExperiment(let detail): "Invalid experiment JSON returned by albertlmctl: \(detail)"
        case .invalidDatasets(let detail): "Invalid datasets JSON returned by albertlmctl: \(detail)"
        }
    }
}

actor AlbertLMNodeService {
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
        let command = ([script] + arguments.map(shellQuote)).joined(separator: " ")
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
            // The current controller emits six headerless columns:
            // name, temperature, utilization, memory used, memory total, power draw.
            // Seven-column output is also accepted for older controller exports.
            let indexes: GPUCSVIndexes
            if hasHeader {
                indexes = headerIndexes
            } else if row.count == 6 {
                indexes = GPUCSVIndexes(name: 0, temperature: 1, powerDraw: 5, powerLimit: nil, memoryUsed: 3, memoryTotal: 4, utilization: 2)
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

    func system() async throws -> SystemStatus {
        let text = try await execute(.system)
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidSystem("Not UTF-8") }
        do {
            return try JSONDecoder().decode(SystemStatus.self, from: data)
        } catch {
            throw NodeServiceError.invalidSystem(error.localizedDescription)
        }
    }

    func checkpoints() async throws -> [Checkpoint] {
        let text = try await execute(.checkpoints)
        guard let data = text.data(using: .utf8) else { throw NodeServiceError.invalidCheckpoints("Not UTF-8") }
        do {
            if let values = try? JSONDecoder().decode([Checkpoint].self, from: data) {
                return values
            }
            return try JSONDecoder().decode(CheckpointEnvelope.self, from: data).checkpoints
        } catch {
            throw NodeServiceError.invalidCheckpoints(error.localizedDescription)
        }
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

private struct CheckpointEnvelope: Decodable {
    let checkpoints: [Checkpoint]

    enum CodingKeys: String, CodingKey { case checkpoints, items, files }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        checkpoints = try values.decodeIfPresent([Checkpoint].self, forKey: .checkpoints)
            ?? values.decodeIfPresent([Checkpoint].self, forKey: .items)
            ?? values.decodeIfPresent([Checkpoint].self, forKey: .files)
            ?? []
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
