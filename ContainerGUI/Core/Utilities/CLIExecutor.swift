import Foundation
import os

public enum CLIError: LocalizedError {
    case commandNotFound(String)
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .commandNotFound(let cmd):
            return "Command not found: \(cmd)"
        case .executionFailed(let cmd, let code, let stderr):
            return "\(cmd) failed (exit \(code)): \(stderr)"
        case .invalidOutput(let details):
            return "Invalid output: \(details)"
        }
    }
}

public actor CLIExecutor {
    private let commandPath: String
    private let environment: [String: String]

    public init(commandPath: String? = nil, environment: [String: String] = [:]) {
        self.commandPath = commandPath ?? Self.resolveCommandPath()
        self.environment = environment
    }

    private static func resolveCommandPath() -> String {
        let candidates = [
            "/usr/local/bin/container",
            "/opt/homebrew/bin/container",
            "/usr/bin/container",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "container"
    }

    /// Returns true if the `container` CLI binary can be found in PATH or known locations.
    public static func isCLIInstalled() -> Bool {
        let resolved = resolveCommandPath()
        if resolved != "container" { return true }
        // Fallback: check if `container` is findable via PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "container"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    public func run(arguments: [String], debug: Bool = false, input: String? = nil) async throws -> String {
        let cmd = ([commandPath] + arguments).joined(separator: " ")
        print("[CLI] \(cmd)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [commandPath] + arguments

        var env = ProcessInfo.processInfo.environment
        if debug { env["CONTAINER_DEBUG"] = "1" }
        for (key, value) in environment { env[key] = value }
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Pipe input for commands that prompt (e.g. prune)
        if let input {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            // Write input on a non-actor thread to avoid blocking
            Task.detached {
                inputPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
                inputPipe.fileHandleForWriting.closeFile()
            }
        }

        // Thread-safe buffers using OSAllocatedUnfairLock (macOS 13+).
        // readabilityHandler runs on a non-actor thread while the actor
        // reads the final data after the process exits — the lock prevents data races.
        let outputData = OSAllocatedUnfairLock(initialState: Data())
        let errorData = OSAllocatedUnfairLock(initialState: Data())

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.withLock { $0.append(data) }
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.withLock { $0.append(data) }
            }
        }

        try process.run()
        process.waitUntilExit()

        // Give the last readabilityHandler callback time to fire
        try await Task.sleep(for: .milliseconds(50))
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        // Read any remaining data
        let finalOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let finalError = errorPipe.fileHandleForReading.readDataToEndOfFile()
        outputData.withLock { $0.append(finalOutput) }
        errorData.withLock { $0.append(finalError) }

        let output = String(data: outputData.withLock { $0 }, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData.withLock { $0 }, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let msg = "\(cmd) failed (exit \(process.terminationStatus)): \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
            print("[CLI] ⚠️ \(msg)")
            throw CLIError.executionFailed(
                command: cmd,
                exitCode: process.terminationStatus,
                stderr: errorOutput
            )
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func runJSON<T: Decodable & Sendable>(_ type: T.Type, arguments: [String], debug: Bool = false) async throws -> T {
        let output = try await run(arguments: arguments, debug: debug)
        print("[CLI] → JSON (\(output.count) bytes)")
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "{}" {
            if let arr = [] as? T { return arr }
            throw CLIError.invalidOutput("Unexpected empty object")
        }
        guard let data = output.data(using: .utf8) else {
            throw CLIError.invalidOutput("Could not encode output as UTF-8")
        }
        // Decode in a detached task so Decodable conformance doesn't
        // need to be available from this actor's isolation domain.
        return try await Task.detached {
            try JSONDecoder().decode(type, from: data)
        }.value
    }

    /// Stream stdout + stderr from a long-running command.
    public func streamOutput(arguments: [String]) -> AsyncThrowingStream<String, Error> {
        let cmd = commandPath
        let fullCmd = ([commandPath] + arguments).joined(separator: " ")
        print("[CLI] \(fullCmd) (stream)")
        return AsyncThrowingStream { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [cmd] + arguments

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                do {
                    try process.run()
                    let handle = outputPipe.fileHandleForReading

                    while true {
                        let data = handle.availableData
                        if data.isEmpty { break }
                        if var chunk = String(data: data, encoding: .utf8) {
                            chunk = chunk.replacingOccurrences(of: "\r\n", with: "\n")
                                .replacingOccurrences(of: "\r", with: "\n")
                            continuation.yield(chunk)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
