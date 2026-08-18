import Foundation

/// The single process primitive. Reused by MoleService for every `mo` call.
/// ponytail: one concrete type, no protocol/DI — add a fake only if tests need one.
enum ProcessRunner {

    struct Result {
        var stdout: String
        var stderr: String
        var exitCode: Int32
    }

    /// Run a binary to completion, capturing stdout/stderr. Pipes are drained on
    /// background queues *before* the process exits to avoid the classic full-pipe deadlock.
    static func run(_ launchPath: String, _ args: [String]) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = args

            let outPipe = Pipe(), errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            // Collect asynchronously so large output can't fill and block the pipe.
            let outData = DataBox(), errData = DataBox()
            outPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil } else { outData.append(d) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil } else { errData.append(d) }
            }

            process.terminationHandler = { proc in
                // Flush anything left buffered after exit.
                outData.append(outPipe.fileHandleForReading.readDataToEndOfFile())
                errData.append(errPipe.fileHandleForReading.readDataToEndOfFile())
                continuation.resume(returning: Result(
                    stdout: outData.string,
                    stderr: errData.string,
                    exitCode: proc.terminationStatus
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: MoleError.launch(error))
            }
        }
    }
}

/// Thread-safe accumulator for a readability handler firing off arbitrary queues.
private final class DataBox: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
    var string: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
}
