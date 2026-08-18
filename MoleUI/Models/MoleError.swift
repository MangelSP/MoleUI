import Foundation

enum MoleError: LocalizedError {
    case notInstalled
    case exitCode(Int32, stderr: String)
    case decode(underlying: Error)
    case launch(Error)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "The Mole CLI (`mo`) was not found. Install it to continue."
        case .exitCode(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "`mo` exited with code \(code)." + (detail.isEmpty ? "" : "\n\(detail)")
        case .decode:
            return "Could not read Mole's output. The CLI version may be incompatible."
        case .launch(let error):
            return "Could not run `mo`: \(error.localizedDescription)"
        }
    }
}
