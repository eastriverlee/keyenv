#if os(Linux)
import Foundation

struct SecretServiceStore: SecretStore {
    private struct ToolResult {
        let exitCode: Int32
        let standardOutput: String
        let standardError: String
    }

    private static let missingToolAdvice = """
    monkeys needs the secret-tool command, which talks to the Secret Service \
    your desktop keyring provides. Install it with your package manager \
    (libsecret-tools on Debian and Ubuntu, libsecret on Fedora and Arch).
    """

    private func run(_ arguments: [String], input: String? = nil) throws -> ToolResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["secret-tool"] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        if input != nil { process.standardInput = Pipe() }

        do {
            try process.run()
        } catch {
            throw StoreFailure.backendUnavailable(Self.missingToolAdvice)
        }

        if let input, let inputPipe = process.standardInput as? Pipe {
            inputPipe.fileHandleForWriting.write(Data(input.utf8))
            inputPipe.fileHandleForWriting.closeFile()
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus == 127 { throw StoreFailure.backendUnavailable(Self.missingToolAdvice) }
        return ToolResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func attributes(forName name: String) -> [String] {
        ["service", serviceName, "account", name]
    }

    func store(_ value: String, forName name: String) throws {
        let result = try run(
            ["store", "--label", "\(serviceName): \(name)"] + attributes(forName: name),
            input: value
        )
        guard result.exitCode == 0 else {
            throw StoreFailure.backendFailed("secret-tool store failed: \(result.standardError)")
        }
    }

    func read(forName name: String) throws -> String {
        let result = try run(["lookup"] + attributes(forName: name))
        guard result.exitCode == 0, !result.standardOutput.isEmpty else {
            if !result.standardError.isEmpty {
                throw StoreFailure.backendFailed("secret-tool lookup failed: \(result.standardError)")
            }
            throw StoreFailure.keyNotStored(name)
        }
        return result.standardOutput
    }

    func remove(forName name: String) throws {
        guard (try? read(forName: name)) != nil else { throw StoreFailure.keyNotStored(name) }
        let result = try run(["clear"] + attributes(forName: name))
        guard result.exitCode == 0 else {
            throw StoreFailure.backendFailed("secret-tool clear failed: \(result.standardError)")
        }
    }

    func storedKeys() throws -> [String] {
        let result = try run(["search", "--all", "service", serviceName])
        let prefix = "attribute.account = "
        let keys = result.standardError.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix(prefix) else { return nil }
            return String(line.dropFirst(prefix.count))
        }
        if keys.isEmpty, result.exitCode != 0, !result.standardError.isEmpty {
            throw StoreFailure.backendFailed("secret-tool search failed: \(result.standardError)")
        }
        return Array(Set(keys)).sorted()
    }
}
#endif
