import Foundation

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
    case commandFailed(code: Int32, message: String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            "SSH host is empty. Open Settings and configure the remote node."
        case .launchFailed(let message):
            "Could not launch system SSH: \(message)"
        case .commandFailed(let code, let message):
            message.isEmpty ? "SSH command failed with exit code \(code)." : message
        case .invalidOutput:
            "The remote node returned text that is not valid UTF-8."
        }
    }
}

actor SSHService {
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

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=2",
            configuration.destination,
            command
        ]
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { completed in
                    let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: outputData, encoding: .utf8),
                          let error = String(data: errorData, encoding: .utf8) else {
                        continuation.resume(throwing: SSHError.invalidOutput)
                        return
                    }
                    guard completed.terminationStatus == 0 else {
                        let message = error.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: SSHError.commandFailed(code: completed.terminationStatus, message: message))
                        return
                    }
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SSHError.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
