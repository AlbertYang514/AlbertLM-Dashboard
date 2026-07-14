import Foundation
import OSLog

struct SSHConfiguration: Sendable, Equatable {
    var host: String
    var username: String

    var destination: String {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUser.isEmpty ? trimmedHost : "\(trimmedUser)@\(trimmedHost)"
    }
}

enum SSHError: LocalizedError {
    case invalidHost
    case launchFailed(String)
    case commandFailed(code: Int32, command: String, message: String)
    case timedOut(command: String, seconds: Int)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "SSH host is empty. Open Settings and configure the remote node."
        case .launchFailed(let message):
            return "Could not launch system SSH: \(message)"
        case .commandFailed(let code, let command, let message):
            let prefix = "SSH command failed with exit code \(code): \(command)"
            return message.isEmpty ? prefix : "\(prefix)\n\(message)"
        case .timedOut(let command, let seconds):
            return "SSH command timed out after \(seconds) seconds: \(command)"
        case .invalidOutput:
            return "The remote node returned text that is not valid UTF-8."
        }
    }
}

actor SSHService {
    private static let logger = Logger(subsystem: "com.albertyang.AlbertLMDashboard", category: "SSH")
    private static let commandTimeoutSeconds = 20
    private var configuration: SSHConfiguration

    init(configuration: SSHConfiguration) {
        self.configuration = configuration
    }

    func update(configuration: SSHConfiguration) {
        self.configuration = configuration
    }

    /// Runs a command through macOS' system SSH client. Authentication is delegated
    /// entirely to ~/.ssh/config, SSH keys and the user's existing ssh-agent.
    func run(command: String) async throws -> String {
        guard !configuration.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SSHError.invalidHost
        }

        let destination = configuration.destination
        let timeout = Self.commandTimeoutSeconds

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await Self.runProcess(destination: destination, command: command)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                Self.logger.error("SSH timeout host=\(destination, privacy: .public) command=\(command, privacy: .public)")
                throw SSHError.timedOut(command: command, seconds: timeout)
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw SSHError.launchFailed("SSH task ended without a result.")
            }
            return result
        }
    }

    private static func runProcess(destination: String, command: String) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let outputBuffer = LockedDataBuffer()
        let errorBuffer = LockedDataBuffer()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=2",
            destination,
            command
        ]
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { outputBuffer.append(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { errorBuffer.append(data) }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { completed in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    outputBuffer.append(stdout.fileHandleForReading.readDataToEndOfFile())
                    errorBuffer.append(stderr.fileHandleForReading.readDataToEndOfFile())

                    guard let output = String(data: outputBuffer.data, encoding: .utf8),
                          let error = String(data: errorBuffer.data, encoding: .utf8) else {
                        logger.error("SSH returned invalid UTF-8 host=\(destination, privacy: .public) command=\(command, privacy: .public)")
                        continuation.resume(throwing: SSHError.invalidOutput)
                        return
                    }
                    guard completed.terminationStatus == 0 else {
                        let message = error.trimmingCharacters(in: .whitespacesAndNewlines)
                        logger.error("SSH failure host=\(destination, privacy: .public) exit=\(completed.terminationStatus) command=\(command, privacy: .public) stderr=\(message, privacy: .public)")
                        continuation.resume(throwing: SSHError.commandFailed(
                            code: completed.terminationStatus,
                            command: command,
                            message: message
                        ))
                        return
                    }
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                do {
                    try Task.checkCancellation()
                    try process.run()
                    if Task.isCancelled, process.isRunning { process.terminate() }
                } catch {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    logger.error("SSH launch failed host=\(destination, privacy: .public) command=\(command, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: SSHError.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
