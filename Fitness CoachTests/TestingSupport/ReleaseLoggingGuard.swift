//
//  ReleaseLoggingGuard.swift
//  Fitness CoachTests
//
//  Forma — Scans production Swift for Release-reachable logging outside the allowlist.
//

import Foundation

struct ReleaseLoggingSite: Equatable {
    let relativePath: String
    let line: Int
    let pattern: String
    let lineContent: String
}

struct ReleaseLoggingViolation: Equatable {
    let site: ReleaseLoggingSite
    let reason: String

    var diagnosticMessage: String {
        """
        \(site.relativePath):\(site.line) [\(site.pattern)] — \(reason)
          \(site.lineContent.trimmingCharacters(in: .whitespaces))
        """
    }
}

struct ReleaseLoggingAllowlist: Decodable {
    struct FileEntry: Decodable {
        let path: String
        let owner: String
        let reason: String
        let sensitivity: String
        let redactorRequired: Bool
        let redactorSymbols: [String]
    }

    struct LinePatternEntry: Decodable {
        let id: String
        let pattern: String
        let owner: String
        let reason: String
        let sensitivity: String
        let redactorRequired: Bool
        let redactorSymbols: [String]?
        let debugCalleeFile: String?
    }

    struct DebugOnlyFile: Decodable {
        let path: String
        let gate: String
        let owner: String
        let reason: String
    }

    let version: Int
    let fileEntries: [FileEntry]
    let linePatternEntries: [LinePatternEntry]
    let debugOnlyFiles: [DebugOnlyFile]
}

enum ReleaseLoggingGuard {

    static let scannedSourceDirectory = "Fitness Coach"
    static let allowlistFixtureName = "ReleaseLoggingAllowlist.json"

    static let emissionPatterns: [(name: String, regex: String)] = [
        ("logger.log", #"\.log\s*\("#),
        ("logger.level", #"logger\.(debug|info|warning|error|notice|critical|trace)\s*\("#),
        ("print", #"\bprint\s*\("#),
        ("debugPrint", #"\bdebugPrint\s*\("#),
        ("NSLog", #"\bNSLog\s*\("#),
        ("os_log", #"\bos_log\s*\("#),
        ("OSLog", #"\bOSLog\s*\("#),
        ("Logger(", #"Logger\s*\("#)
    ]

    static func loadAllowlist(repositoryRoot: URL) throws -> ReleaseLoggingAllowlist {
        let url = repositoryRoot
            .appendingPathComponent("Fitness CoachTests/Fixtures", isDirectory: true)
            .appendingPathComponent(allowlistFixtureName)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ReleaseLoggingAllowlist.self, from: data)
    }

    static func scan(repositoryRoot: URL, allowlist: ReleaseLoggingAllowlist) -> [ReleaseLoggingViolation] {
        let sourceRoot = repositoryRoot.appendingPathComponent(scannedSourceDirectory, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var violations: [ReleaseLoggingViolation] = []
        let fileContents = loadFileContents(enumerator: enumerator, repositoryRoot: repositoryRoot)

        for (relativePath, content) in fileContents.sorted(by: { $0.key < $1.key }) {
            let sites = releaseReachableSites(in: content, relativePath: relativePath)
            for site in sites {
                if let violation = validate(site: site, content: content, allowlist: allowlist, fileContents: fileContents) {
                    violations.append(violation)
                }
            }
        }

        return violations.sorted {
            $0.site.relativePath == $1.site.relativePath
                ? $0.site.line < $1.site.line
                : $0.site.relativePath < $1.site.relativePath
        }
    }

    // MARK: - Scanning

    static func releaseReachableSites(in content: String, relativePath: String) -> [ReleaseLoggingSite] {
        let lines = content.components(separatedBy: .newlines)
        var stack: [PreprocessorBranch] = []
        var debugOnlyAfterElseReturn = false
        var previewBraceBalance = 0
        var blockCommentDepth = 0
        var sites: [ReleaseLoggingSite] = []

        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            var line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("/*") { blockCommentDepth += 1 }
            if blockCommentDepth > 0 {
                if trimmed.contains("*/") { blockCommentDepth = max(0, blockCommentDepth - 1) }
                continue
            }

            if let commentStart = line.range(of: "//") {
                line = String(line[..<commentStart.lowerBound])
            }

            if previewBraceBalance == 0, trimmed.hasPrefix("#Preview") {
                previewBraceBalance += braceDelta(in: line)
                continue
            }
            if previewBraceBalance > 0 {
                previewBraceBalance += braceDelta(in: line)
                continue
            }

            if trimmed.hasPrefix("#if DEBUG") {
                stack.append(.init(kind: .debug, inElse: false))
            } else if trimmed.hasPrefix("#if !DEBUG") || trimmed.hasPrefix("#if ! DEBUG") {
                stack.append(.init(kind: .notDebug, inElse: false))
            } else if trimmed == "#else" {
                if !stack.isEmpty {
                    stack[stack.count - 1].inElse = true
                }
            } else if trimmed.hasPrefix("#endif") {
                if let ended = stack.popLast(), ended.kind == .debug, ended.inElse {
                    debugOnlyAfterElseReturn = containsElseReturnGate(in: lines, endingAt: index)
                }
            }

            if trimmed.hasPrefix("func ") || trimmed.contains(" func ") {
                debugOnlyAfterElseReturn = false
            }

            let releaseReachable = isReleaseReachable(stack: stack, debugOnlyAfterElseReturn: debugOnlyAfterElseReturn)
            guard releaseReachable else { continue }

            for (name, regex) in emissionPatterns {
                guard let expression = try? NSRegularExpression(pattern: regex) else { continue }
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard expression.firstMatch(in: line, range: range) != nil else { continue }

                if name == "Logger(", isLoggerDeclaration(line: line) { continue }

                sites.append(
                    ReleaseLoggingSite(
                        relativePath: relativePath,
                        line: lineNumber,
                        pattern: name,
                        lineContent: rawLine
                    )
                )
            }
        }

        return sites
    }

    // MARK: - Validation

    private static func validate(
        site: ReleaseLoggingSite,
        content: String,
        allowlist: ReleaseLoggingAllowlist,
        fileContents: [String: String]
    ) -> ReleaseLoggingViolation? {
        if let debugOnly = allowlist.debugOnlyFiles.first(where: { $0.path == site.relativePath }) {
            if verifyDebugOnlyGate(debugOnly, content: content) {
                return nil
            }
            return ReleaseLoggingViolation(
                site: site,
                reason: "DEBUG-only file \(debugOnly.path) is missing required gate `\(debugOnly.gate)`"
            )
        }

        if let fileEntry = allowlist.fileEntries.first(where: { $0.path == site.relativePath }) {
            if fileEntry.redactorRequired, !containsRedactorSymbols(fileEntry.redactorSymbols, in: content) {
                return ReleaseLoggingViolation(
                    site: site,
                    reason: "Allowlisted file requires redactor symbols: \(fileEntry.redactorSymbols.joined(separator: ", "))"
                )
            }
            return nil
        }

        for patternEntry in allowlist.linePatternEntries {
            guard matchesPattern(patternEntry.pattern, in: site.lineContent) else { continue }

            if let calleePath = patternEntry.debugCalleeFile,
               let calleeContent = fileContents[calleePath],
               !calleeFunctionIsDebugOnly(calleeContent) {
                return ReleaseLoggingViolation(
                    site: site,
                    reason: "Pattern `\(patternEntry.id)` requires DEBUG-only callee in \(calleePath)"
                )
            }

            if patternEntry.redactorRequired,
               let symbols = patternEntry.redactorSymbols,
               !containsRedactorSymbols(symbols, in: fileContents[site.relativePath] ?? content) {
                return ReleaseLoggingViolation(
                    site: site,
                    reason: "Pattern `\(patternEntry.id)` requires redactor symbols: \(symbols.joined(separator: ", "))"
                )
            }

            return nil
        }

        return ReleaseLoggingViolation(
            site: site,
            reason: "Release-reachable logging not in ReleaseLoggingAllowlist.json — add a specific entry to Docs/Architecture/ReleaseLoggingAllowlist.md"
        )
    }

    // MARK: - Helpers

    private struct PreprocessorBranch {
        enum Kind { case debug, notDebug }
        let kind: Kind
        var inElse: Bool
    }

    private static func isReleaseReachable(stack: [PreprocessorBranch], debugOnlyAfterElseReturn: Bool) -> Bool {
        if debugOnlyAfterElseReturn { return false }
        for branch in stack {
            switch branch.kind {
            case .debug where !branch.inElse:
                return false
            case .notDebug where branch.inElse:
                return false
            default:
                continue
            }
        }
        return true
    }

    private static func containsElseReturnGate(in lines: [String], endingAt endifIndex: Int) -> Bool {
        for index in stride(from: endifIndex - 1, through: max(0, endifIndex - 12), by: -1) {
            if lines[index].trimmingCharacters(in: .whitespaces) == "#else" {
                let elseBody = lines[(index + 1)..<endifIndex]
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("//") }
                return elseBody == ["return"]
            }
        }
        return false
    }

    private static func verifyDebugOnlyGate(_ entry: ReleaseLoggingAllowlist.DebugOnlyFile, content: String) -> Bool {
        switch entry.gate {
        case "else-return":
            return content.contains("#if DEBUG") && content.contains("#else") && content.contains("return")
        case "file-debug-implementation":
            return content.contains("#if DEBUG") && content.contains("#else")
        default:
            return false
        }
    }

    private static func isLoggerDeclaration(line: String) -> Bool {
        line.contains("= Logger(") || line.hasSuffix("Logger(")
    }

    private static func containsRedactorSymbols(_ symbols: [String], in content: String) -> Bool {
        guard !symbols.isEmpty else { return true }
        return symbols.contains { content.contains($0) }
    }

    private static func matchesPattern(_ pattern: String, in line: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }

    private static func calleeFunctionIsDebugOnly(_ content: String) -> Bool {
        guard let range = content.range(of: "static func log") else { return false }
        let suffix = String(content[range.lowerBound...].prefix(500))
        return suffix.contains("#if DEBUG")
    }

    private static func loadFileContents(enumerator: FileManager.DirectoryEnumerator, repositoryRoot: URL) -> [String: String] {
        var result: [String: String] = [:]
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let relative = relativePath(for: fileURL, repositoryRoot: repositoryRoot)
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                result[relative] = content
            }
        }
        return result
    }

    private static func relativePath(for url: URL, repositoryRoot: URL) -> String {
        let root = repositoryRoot.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        if full.hasPrefix(root + "/") {
            return String(full.dropFirst(root.count + 1))
        }
        return full
    }

    private static func braceDelta(in line: String) -> Int {
        line.reduce(0) { partial, character in
            switch character {
            case "{": return partial + 1
            case "}": return partial - 1
            default: return partial
            }
        }
    }
}
