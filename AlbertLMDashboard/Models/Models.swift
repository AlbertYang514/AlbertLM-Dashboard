import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case training = "Training"
    case teachers = "Teachers"
    case experiments = "Experiments"
    case datasets = "Datasets"
    case hardware = "Hardware"
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
        case .hardware: "gauge.with.dots.needle.67percent"
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

struct WorkstationStatus: Decodable, Equatable {
    let cpu: CPUHardwareStatus?
    let gpu: GPUHardwareStatus?
    let memory: MemoryHardwareStatus?
    let disk: DiskHardwareStatus?
    let system: OperatingSystemStatus?

    static let empty = WorkstationStatus(cpu: nil, gpu: nil, memory: nil, disk: nil, system: nil)

    enum CodingKeys: String, CodingKey { case cpu, gpu, memory, disk, system }

    init(cpu: CPUHardwareStatus?, gpu: GPUHardwareStatus?, memory: MemoryHardwareStatus?, disk: DiskHardwareStatus?, system: OperatingSystemStatus?) {
        self.cpu = cpu
        self.gpu = gpu
        self.memory = memory
        self.disk = disk
        self.system = system
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cpu = try values.decodeIfPresent(CPUHardwareStatus.self, forKey: .cpu)
        gpu = try values.decodeIfPresent(GPUHardwareStatus.self, forKey: .gpu)
        memory = try values.decodeIfPresent(MemoryHardwareStatus.self, forKey: .memory)
        disk = try values.decodeIfPresent(DiskHardwareStatus.self, forKey: .disk)
        system = try values.decodeIfPresent(OperatingSystemStatus.self, forKey: .system)
    }
}

struct TrainingMetric: Decodable, Equatable, Identifiable {
    let step: Int
    let tokensSeen: Int64
    let trainLoss: Double
    let learningRate: Double
    let gradNorm: Double?
    let tokensPerSecond: Double
    let timestamp: String

    var id: String { "\(step)|\(timestamp)" }

    enum CodingKeys: String, CodingKey {
        case step, timestamp
        case tokensSeen = "tokens_seen"
        case trainLoss = "train_loss"
        case learningRate = "learning_rate"
        case gradNorm = "grad_norm"
        case tokensPerSecond = "tokens_per_second"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        step = try values.decodeFlexibleInt(forKey: .step) ?? 0
        tokensSeen = try values.decodeFlexibleInt64(forKey: .tokensSeen) ?? 0
        trainLoss = try values.decodeFlexibleDouble(forKey: .trainLoss) ?? 0
        learningRate = try values.decodeFlexibleDouble(forKey: .learningRate) ?? 0
        gradNorm = try values.decodeFlexibleDouble(forKey: .gradNorm)
        tokensPerSecond = try values.decodeFlexibleDouble(forKey: .tokensPerSecond) ?? 0
        timestamp = try values.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }
}

struct SystemHistorySample: Decodable, Equatable, Identifiable {
    let timestamp: String
    let snapshot: WorkstationStatus

    var id: String { timestamp }

    enum CodingKeys: String, CodingKey { case timestamp }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try values.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        snapshot = try WorkstationStatus(from: decoder)
    }
}

struct CPUHardwareStatus: Decodable, Equatable {
    let model: String?
    let cores: String?
    let threads: String?
    let frequency: String?
    let usage: String?
    let perCore: [CPUCoreUsage]?
    let temperature: String?

    enum CodingKeys: String, CodingKey {
        case model, cores, threads, frequency, usage, temperature
        case perCore = "per_core"
    }
}

struct CPUCoreUsage: Decodable, Equatable, Identifiable {
    let core: String
    let usage: String
    var id: String { core }
}

struct GPUHardwareStatus: Decodable, Equatable {
    let model: String?
    let memoryUsed: String?
    let memoryTotal: String?
    let utilization: String?
    let temperature: String?
    let power: String?

    enum CodingKeys: String, CodingKey {
        case model, utilization, temperature, power
        case memoryUsed = "memory_used"
        case memoryTotal = "memory_total"
    }
}

struct MemoryHardwareStatus: Decodable, Equatable {
    let total: String?
    let used: String?
    let available: String?
    let usage: String?
    let swap: SwapHardwareStatus?

    enum CodingKeys: String, CodingKey {
        case total, used, available, usage, swap
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        total = values.decodeLossyString(forKey: .total)
        used = values.decodeLossyString(forKey: .used)
        available = values.decodeLossyString(forKey: .available)
        usage = values.decodeLossyString(forKey: .usage)
        swap = try values.decodeIfPresent(SwapHardwareStatus.self, forKey: .swap)
    }
}

struct SwapHardwareStatus: Decodable, Equatable {
    let total: String?
    let used: String?
    let remaining: String?

    enum CodingKeys: String, CodingKey {
        case total, used, remaining
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        total = values.decodeLossyString(forKey: .total)
        used = values.decodeLossyString(forKey: .used)
        remaining = values.decodeLossyString(forKey: .remaining)
    }
}

struct DiskHardwareStatus: Decodable, Equatable {
    let system: DiskVolumeStatus?
    let data: DiskVolumeStatus?
    let ssdTemperatures: [SSDTemperature]?

    enum CodingKeys: String, CodingKey {
        case system, data
        case ssdTemperatures = "ssd_temperatures"
    }
}

struct DiskVolumeStatus: Decodable, Equatable {
    let mount: String?
    let total: String?
    let used: String?
    let available: String?
    let usage: String?
}

struct SSDTemperature: Decodable, Equatable, Identifiable {
    let device: String
    let temperature: String
    var id: String { device }
}

struct OperatingSystemStatus: Decodable, Equatable {
    let ubuntu: String?
    let kernel: String?
    let cuda: String?
    let nvidiaDriver: String?
    let uptime: String?

    enum CodingKeys: String, CodingKey {
        case ubuntu, kernel, cuda, uptime
        case nvidiaDriver = "nvidia_driver"
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

struct CheckpointIndex: Decodable, Equatable {
    let schemaVersion: Int?
    let generatedAt: String?
    let latest: CheckpointRecord?
    let checkpoints: [CheckpointRecord]

    static let empty = CheckpointIndex(schemaVersion: nil, generatedAt: nil, latest: nil, checkpoints: [])

    enum CodingKeys: String, CodingKey {
        case latest, checkpoints
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
    }

    init(schemaVersion: Int?, generatedAt: String?, latest: CheckpointRecord?, checkpoints: [CheckpointRecord]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.latest = latest
        self.checkpoints = checkpoints
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeFlexibleInt(forKey: .schemaVersion)
        generatedAt = try values.decodeIfPresent(String.self, forKey: .generatedAt)
        latest = try values.decodeIfPresent(CheckpointRecord.self, forKey: .latest)
        checkpoints = try values.decodeIfPresent([CheckpointRecord].self, forKey: .checkpoints) ?? []
    }
}

struct CheckpointRecord: Decodable, Identifiable, Equatable {
    let step: Int
    let tokens: Int64
    let path: String
    let modelStatePath: String?
    let modelStateBytes: Int64
    let modifiedAt: String

    var id: String { "\(step)|\(path)" }

    enum CodingKeys: String, CodingKey {
        case step, tokens, path
        case modelStatePath = "model_state_path"
        case modelStateBytes = "model_state_bytes"
        case modifiedAt = "modified_at"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        step = try values.decodeFlexibleInt(forKey: .step) ?? 0
        tokens = try values.decodeFlexibleInt64(forKey: .tokens) ?? 0
        path = try values.decodeIfPresent(String.self, forKey: .path) ?? ""
        modelStatePath = try values.decodeIfPresent(String.self, forKey: .modelStatePath)
        modelStateBytes = try values.decodeFlexibleInt64(forKey: .modelStateBytes) ?? 0
        modifiedAt = try values.decodeIfPresent(String.self, forKey: .modifiedAt) ?? ""
    }
}

struct EvaluationLatest: Decodable, Equatable {
    let schemaVersion: Int?
    let updatedAt: String?
    let latestValidLoss: Double?
    let latestValidLossStep: Int?
    let latestValidLossTokens: Int64?
    let latestValidEvalTokens: Int64?
    let latestValidPPL: Double?
    let latestValidPPLStep: Int?
    let latestValidPPLTokens: Int64?
    let latestSampleStep: Int?
    let latestSampleTokens: Int64?
    let latestSamplePath: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case updatedAt = "updated_at"
        case latestValidLoss = "latest_valid_loss"
        case latestValidLossStep = "latest_valid_loss_step"
        case latestValidLossTokens = "latest_valid_loss_tokens"
        case latestValidEvalTokens = "latest_valid_eval_tokens"
        case latestValidPPL = "latest_valid_ppl"
        case latestValidPPLStep = "latest_valid_ppl_step"
        case latestValidPPLTokens = "latest_valid_ppl_tokens"
        case latestSampleStep = "latest_sample_step"
        case latestSampleTokens = "latest_sample_tokens"
        case latestSamplePath = "latest_sample_path"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeFlexibleInt(forKey: .schemaVersion)
        updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt)
        latestValidLoss = try values.decodeFlexibleDouble(forKey: .latestValidLoss)
        latestValidLossStep = try values.decodeFlexibleInt(forKey: .latestValidLossStep)
        latestValidLossTokens = try values.decodeFlexibleInt64(forKey: .latestValidLossTokens)
        latestValidEvalTokens = try values.decodeFlexibleInt64(forKey: .latestValidEvalTokens)
        latestValidPPL = try values.decodeFlexibleDouble(forKey: .latestValidPPL)
        latestValidPPLStep = try values.decodeFlexibleInt(forKey: .latestValidPPLStep)
        latestValidPPLTokens = try values.decodeFlexibleInt64(forKey: .latestValidPPLTokens)
        latestSampleStep = try values.decodeFlexibleInt(forKey: .latestSampleStep)
        latestSampleTokens = try values.decodeFlexibleInt64(forKey: .latestSampleTokens)
        latestSamplePath = try values.decodeIfPresent(String.self, forKey: .latestSamplePath)
    }
}

struct EvaluationMetric: Decodable, Identifiable, Equatable {
    let event: String
    let optimizerStep: Int
    let tokensSeen: Int64
    let validLoss: Double?
    let validPPL: Double?
    let evalTokens: Int64?
    let evalBatches: Int?
    let elapsedSeconds: Double?
    let validDataPath: String?
    let timestamp: String

    var id: String { "\(optimizerStep)|\(event)|\(timestamp)" }

    enum CodingKeys: String, CodingKey {
        case event, timestamp
        case optimizerStep = "optimizer_step"
        case tokensSeen = "tokens_seen"
        case validLoss = "valid_loss"
        case validPPL = "valid_ppl"
        case evalTokens = "eval_tokens"
        case evalBatches = "eval_batches"
        case elapsedSeconds = "elapsed_seconds"
        case validDataPath = "valid_data_path"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        event = try values.decodeIfPresent(String.self, forKey: .event) ?? "validation"
        optimizerStep = try values.decodeFlexibleInt(forKey: .optimizerStep) ?? 0
        tokensSeen = try values.decodeFlexibleInt64(forKey: .tokensSeen) ?? 0
        validLoss = try values.decodeFlexibleDouble(forKey: .validLoss)
        validPPL = try values.decodeFlexibleDouble(forKey: .validPPL)
        evalTokens = try values.decodeFlexibleInt64(forKey: .evalTokens)
        evalBatches = try values.decodeFlexibleInt(forKey: .evalBatches)
        elapsedSeconds = try values.decodeFlexibleDouble(forKey: .elapsedSeconds)
        validDataPath = try values.decodeIfPresent(String.self, forKey: .validDataPath)
        timestamp = try values.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }
}

struct GeneratedSampleBatch: Decodable, Identifiable, Equatable {
    let optimizerStep: Int
    let tokensSeen: Int64
    let timestamp: String
    let tokenizerPath: String?
    let temperature: Double?
    let topP: Double?
    let maxNewTokens: Int?
    let elapsedSeconds: Double?
    let samples: [GeneratedSample]

    var id: String { "\(optimizerStep)|\(timestamp)" }

    enum CodingKeys: String, CodingKey {
        case timestamp, temperature, samples
        case optimizerStep = "optimizer_step"
        case tokensSeen = "tokens_seen"
        case tokenizerPath = "tokenizer_path"
        case topP = "top_p"
        case maxNewTokens = "max_new_tokens"
        case elapsedSeconds = "elapsed_seconds"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        optimizerStep = try values.decodeFlexibleInt(forKey: .optimizerStep) ?? 0
        tokensSeen = try values.decodeFlexibleInt64(forKey: .tokensSeen) ?? 0
        timestamp = try values.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        tokenizerPath = try values.decodeIfPresent(String.self, forKey: .tokenizerPath)
        temperature = try values.decodeFlexibleDouble(forKey: .temperature)
        topP = try values.decodeFlexibleDouble(forKey: .topP)
        maxNewTokens = try values.decodeFlexibleInt(forKey: .maxNewTokens)
        elapsedSeconds = try values.decodeFlexibleDouble(forKey: .elapsedSeconds)
        samples = try values.decodeIfPresent([GeneratedSample].self, forKey: .samples) ?? []
    }
}

struct GeneratedSample: Decodable, Equatable {
    let prompt: String
    let completion: String
    let fullText: String?
    let promptTokens: Int?
    let generatedTokens: Int?

    enum CodingKeys: String, CodingKey {
        case prompt, completion
        case fullText = "full_text"
        case promptTokens = "prompt_tokens"
        case generatedTokens = "generated_tokens"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try values.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        completion = try values.decodeIfPresent(String.self, forKey: .completion) ?? ""
        fullText = try values.decodeIfPresent(String.self, forKey: .fullText)
        promptTokens = try values.decodeFlexibleInt(forKey: .promptTokens)
        generatedTokens = try values.decodeFlexibleInt(forKey: .generatedTokens)
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
        let remoteName = values.decodeLossyString(forKey: .name)
        let kindValue = try values.decodeIfPresent(String.self, forKey: .teacher)
            ?? remoteName
            ?? "qwen"
        kind = TeacherKind(rawValue: kindValue.lowercased().replacingOccurrences(of: "-", with: "")) ?? .qwen
        let remoteState = try values.decodeIfPresent(String.self, forKey: .status)
            ?? values.decodeLossyString(forKey: .state)
            ?? "error"
        state = TeacherRunState(remoteValue: remoteState)
        modelName = try values.decodeIfPresent(String.self, forKey: .modelName)
            ?? values.decodeLossyString(forKey: .model)
            ?? remoteName
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

    func decodeFlexibleInt64(forKey key: Key) throws -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int64(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int64(value) }
        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}
