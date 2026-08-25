import Foundation

/// Reads the GitHub CLI's OAuth token via `gh auth token`.
/// Useful when an org blocks classic PATs but allows the GitHub CLI OAuth app.
enum GHCLI {
    static func token() async -> String? {
        await Task.detached {
            let candidates = [
                "/opt/homebrew/bin/gh",
                "/usr/local/bin/gh",
                "/usr/bin/gh",
            ]
            guard let gh = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                return nil
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gh)
            process.arguments = ["auth", "token"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }
            guard process.terminationStatus == 0,
                  let data = try? pipe.fileHandleForReading.readToEnd(),
                  let token = String(data: data, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty
            else { return nil }
            return token
        }.value
    }
}
