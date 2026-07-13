import Foundation

enum TeacherAction: String, Sendable {
    case start
    case stop
    case status
}

enum TeacherServiceError: LocalizedError {
    case invalidResponse(teacher: TeacherKind, detail: String)
    case invalidDatasetArguments

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let teacher, let detail):
            "Invalid \(teacher.displayName) status returned by teacherctl: \(detail)"
        case .invalidDatasetArguments:
            "Dataset input and output must not be empty."
        }
    }
}

actor TeacherService {
    private let ssh: SSHService
    private var projectPath: String

    init(ssh: SSHService, projectPath: String) {
        self.ssh = ssh
        self.projectPath = projectPath
    }

    func update(projectPath: String) {
        self.projectPath = projectPath
    }

    func execute(_ teacher: TeacherKind, action: TeacherAction) async throws -> String {
        let script = shellPath(projectPath) + "/scripts/teacherctl.sh"
        return try await ssh.run(command: "\(script) \(teacher.rawValue) \(action.rawValue)")
    }

    func status(for teacher: TeacherKind) async throws -> TeacherStatus {
        let text = try await execute(teacher, action: .status)
        guard let data = text.data(using: .utf8) else {
            throw TeacherServiceError.invalidResponse(teacher: teacher, detail: "Not UTF-8")
        }
        do {
            let decoded = try JSONDecoder().decode(TeacherStatus.self, from: data)
            return TeacherStatus(
                kind: teacher,
                state: decoded.state,
                modelName: decoded.modelName,
                port: decoded.port,
                gpuUsage: decoded.gpuUsage,
                lastUpdate: decoded.lastUpdate,
                message: decoded.message
            )
        } catch {
            throw TeacherServiceError.invalidResponse(teacher: teacher, detail: error.localizedDescription)
        }
    }

    func generateDataset(teacher: TeacherKind, input: String, output: String) async throws -> String {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty, !trimmedOutput.isEmpty else {
            throw TeacherServiceError.invalidDatasetArguments
        }
        let script = shellPath(projectPath) + "/scripts/datagen.sh"
        let arguments = [teacher.rawValue, trimmedInput, trimmedOutput].map(shellQuote).joined(separator: " ")
        return try await ssh.run(command: "\(script) \(arguments)")
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
}
