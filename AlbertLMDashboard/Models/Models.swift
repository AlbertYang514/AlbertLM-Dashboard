import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case training = "Training"
    case teachers = "Teachers"
    case experiments = "Experiments"
    case datasets = "Datasets"
    case gpu = "GPU"
    case logs = "Logs"
    case checkpoints = "Checkpoints"
    case settings = "Settings"

    var id: Self { self }

    var icon: String {
        switch self {
        case .dashboard: "rectangle.3.group"
        case .training: "play.circle"
        case .teachers: "person.2.wave.2"
        case .experiments: "flask"
        case .datasets: "cylinder.split.1x2"
        case .gpu: "cpu"
        case .logs: "text.alignleft"
        case .checkpoints: "externaldrive"
        case .settings: "gearshape"
        }
    }
}

enum ConnectionState: Equatable {
    case unknown
    case connecting
    case online
    case offline(String)

    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .connecting: "Connecting…"
        case .online: "Online"
        case .offline: "Offline"
        }
    }
}

struct TrainingStatus: Decodable, Equatable {
    let time: String
    let status: String
    let step: Int
    let loss: Double
    let checkpoint: String
    let gpu: String

    static let empty = TrainingStatus(time: "", status: "Unknown", step: 0, loss: 0, checkpoint: "", gpu: "")

    enum CodingKeys: String, CodingKey { case time, status, step, loss, checkpoint, gpu }

    init(time: String, status: String, step: Int, loss: Double, checkpoint: String, gpu: String) {
        self.time = time
        self.status = status
        self.step = step
        self.loss = loss
        self.checkpoint = checkpoint
        self.gpu = gpu
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        time = try values.decodeIfPresent(String.self, forKey: .time) ?? ""
        status = try values.decodeIfPresent(String.self, forKey: .status) ?? "Unknown"
        step = try values.decodeFlexibleInt(forKey: .step) ?? 0
        loss = try values.decodeFlexibleDouble(forKey: .loss) ?? 0
        checkpoint = try values.decodeIfPresent(String.self, forKey: .checkpoint) ?? ""
        gpu = try values.decodeIfPresent(String.self, forKey: .gpu) ?? ""
    }
}

struct GPUStatus: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let temperature: Double?
    let powerDraw: Double?
    let powerLimit: Double?
    let memoryUsed: Double?
    let memoryTotal: Double?
    let utilization: Double?

    var memoryFraction: Double {
        guard let used = memoryUsed, let total = memoryTotal, total > 0 else { return 0 }
        return min(max(used / total, 0), 1)
    }
}

struct SystemStatus: Decodable, Equatable {
    let cpuLoad: String
    let memoryTotal: String
    let memoryUsed: String
    let diskUsed: String

    static let empty = SystemStatus(cpuLoad: "—", memoryTotal: "—", memoryUsed: "—", diskUsed: "—")

    enum CodingKeys: String, CodingKey {
        case cpuLoad = "cpu_load"
        case memoryTotal = "memory_total"
        case memoryUsed = "memory_used"
        case diskUsed = "disk_used"
    }
}

struct ExperimentStatus: Decodable, Equatable {
    let name: String
    let model: String
    let dataset: String
    let step: Int
    let loss: Double
    let status: String
    let checkpoint: String

    static let empty = ExperimentStatus(name: "AlbertLM", model: "—", dataset: "—", step: 0, loss: 0, status: "Unknown", checkpoint: "")

    enum CodingKeys: String, CodingKey { case name, model, dataset, step, loss, status, checkpoint }

    init(name: String, model: String, dataset: String, step: Int, loss: Double, status: String, checkpoint: String) {
        self.name = name
        self.model = model
        self.dataset = dataset
        self.step = step
        self.loss = loss
        self.status = status
        self.checkpoint = checkpoint
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "AlbertLM"
        model = try values.decodeIfPresent(String.self, forKey: .model) ?? "—"
        dataset = try values.decodeIfPresent(String.self, forKey: .dataset) ?? "—"
        step = try values.decodeFlexibleInt(forKey: .step) ?? 0
        loss = try values.decodeFlexibleDouble(forKey: .loss) ?? 0
        status = try values.decodeIfPresent(String.self, forKey: .status) ?? "Unknown"
        checkpoint = try values.decodeIfPresent(String.self, forKey: .checkpoint) ?? ""
    }
}

struct DatasetFile: Decodable, Identifiable, Equatable {
    let name: String
    let size: String
    let updated: String

    var id: String { "\(name)|\(updated)" }

    enum CodingKeys: String, CodingKey { case name, filename, file, size, updated, date, time, modified }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
            ?? values.decodeLossyString(forKey: .filename)
            ?? values.decodeLossyString(forKey: .file)
            ?? "Unknown"
        size = values.decodeLossyString(forKey: .size) ?? "—"
        updated = try values.decodeIfPresent(String.self, forKey: .updated)
            ?? values.decodeLossyString(forKey: .date)
            ?? values.decodeLossyString(forKey: .time)
            ?? values.decodeLossyString(forKey: .modified)
            ?? "—"
    }
}

struct Checkpoint: Decodable, Identifiable, Equatable {
    let name: String
    let size: String
    let date: String

    var id: String { "\(name)|\(date)" }

    enum CodingKeys: String, CodingKey { case name, size, date, time, modified }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        size = values.decodeLossyString(forKey: .size) ?? "—"
        date = try values.decodeIfPresent(String.self, forKey: .date)
            ?? values.decodeLossyString(forKey: .time)
            ?? values.decodeLossyString(forKey: .modified)
            ?? "—"
    }
}

enum TeacherKind: String, CaseIterable, Identifiable, Sendable {
    case qwen
    case deepseek
    case gptoss

    var id: Self { self }

    var displayName: String {
        switch self {
        case .qwen: "Qwen3-8B"
        case .deepseek: "DeepSeek"
        case .gptoss: "GPT-OSS-20B"
        }
    }
}

enum TeacherRunState: String, Equatable, Sendable {
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"

    init(remoteValue: String) {
        let value = remoteValue.lowercased()
        if value.contains("run") || value.contains("online") || value.contains("ready") {
            self = .running
        } else if value.contains("stop") || value.contains("offline") || value.contains("idle") {
            self = .stopped
        } else {
            self = .error
        }
    }
}

struct TeacherStatus: Decodable, Identifiable, Equatable {
    let kind: TeacherKind
    let state: TeacherRunState
    let modelName: String
    let port: String
    let gpuUsage: String
    let lastUpdate: String
    let message: String?

    var id: TeacherKind { kind }

    static func placeholder(for kind: TeacherKind) -> TeacherStatus {
        TeacherStatus(kind: kind, state: .stopped, modelName: kind.displayName, port: "—", gpuUsage: "—", lastUpdate: "—", message: nil)
    }

    enum CodingKeys: String, CodingKey {
        case teacher, name, status, state, model, modelName = "model_name"
        case port, gpu, gpuUsage = "gpu_usage", updated, time, lastUpdate = "last_update", message, error
    }

    init(kind: TeacherKind, state: TeacherRunState, modelName: String, port: String, gpuUsage: String, lastUpdate: String, message: String?) {
        self.kind = kind
        self.state = state
        self.modelName = modelName
        self.port = port
        self.gpuUsage = gpuUsage
        self.lastUpdate = lastUpdate
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let kindValue = try values.decodeIfPresent(String.self, forKey: .teacher)
            ?? values.decodeLossyString(forKey: .name)
            ?? "qwen"
        kind = TeacherKind(rawValue: kindValue.lowercased().replacingOccurrences(of: "-", with: "")) ?? .qwen
        let remoteState = try values.decodeIfPresent(String.self, forKey: .status)
            ?? values.decodeLossyString(forKey: .state)
            ?? "error"
        state = TeacherRunState(remoteValue: remoteState)
        modelName = try values.decodeIfPresent(String.self, forKey: .modelName)
            ?? values.decodeLossyString(forKey: .model)
            ?? kind.displayName
        port = values.decodeLossyString(forKey: .port) ?? "—"
        gpuUsage = try values.decodeIfPresent(String.self, forKey: .gpuUsage)
            ?? values.decodeLossyString(forKey: .gpu)
            ?? "—"
        lastUpdate = try values.decodeIfPresent(String.self, forKey: .lastUpdate)
            ?? values.decodeLossyString(forKey: .updated)
            ?? values.decodeLossyString(forKey: .time)
            ?? "—"
        message = try values.decodeIfPresent(String.self, forKey: .message)
            ?? values.decodeLossyString(forKey: .error)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}
