//
//  HardcodedColorGuard.swift
//  Fitness CoachTests
//
//  Forma — Scans production Swift for disallowed hardcoded color literals.
//

import Foundation

struct HardcodedColorViolation: Equatable {
    let relativePath: String
    let line: Int
    let matchedPattern: String
    let lineContent: String

    var diagnosticMessage: String {
        """
        \(relativePath):\(line) — matched `\(matchedPattern)`
          \(lineContent.trimmingCharacters(in: .whitespaces))
          Suggested fix: use `FormaTokens.Color.*`, `@Environment(\\.formaColors)`, or register a semantic token in `FormaPaletteCatalog` for every palette/appearance.
        """
    }
}

enum HardcodedColorGuard {

    /// Production sources under this directory are scanned.
    static let scannedSourceDirectory = "Fitness Coach"

    /// Files that may contain raw `Color(red:)` / brand literals.
    static let approvedFileNames: Set<String> = [
        "ThemePaletteCatalog.swift",
        "NeutralAppearanceColors.swift",
        "FormaPaletteCatalog.swift",
        "FormaBrandColorTokens.swift",
        "FormaColorContrast.swift"
    ]

    static let disallowedSystemColorNames = [
        "blue", "pink", "green", "red", "orange", "yellow", "black", "white", "gray", "grey"
    ]

    static func scan(repositoryRoot: URL) -> [HardcodedColorViolation] {
        let sourceRoot = repositoryRoot.appendingPathComponent(scannedSourceDirectory, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var violations: [HardcodedColorViolation] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            guard !isExcluded(path: fileURL, repositoryRoot: repositoryRoot) else { continue }
            violations.append(contentsOf: scanFile(at: fileURL, repositoryRoot: repositoryRoot))
        }
        return violations.sorted {
            $0.relativePath == $1.relativePath
                ? $0.line < $1.line
                : $0.relativePath < $1.relativePath
        }
    }

    // MARK: - File filtering

    private static func isExcluded(path: URL, repositoryRoot: URL) -> Bool {
        let relative = relativePath(for: path, repositoryRoot: repositoryRoot)
        if relative.contains("/Fitness CoachTests/") { return true }
        if approvedFileNames.contains(path.lastPathComponent) { return true }
        return false
    }

    private static func relativePath(for url: URL, repositoryRoot: URL) -> String {
        let root = repositoryRoot.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        if full.hasPrefix(root + "/") {
            return String(full.dropFirst(root.count + 1))
        }
        return full
    }

    // MARK: - Per-file scan

    private static func scanFile(at url: URL, repositoryRoot: URL) -> [HardcodedColorViolation] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let relative = relativePath(for: url, repositoryRoot: repositoryRoot)
        var violations: [HardcodedColorViolation] = []
        var blockCommentDepth = 0
        var previewBraceBalance = 0

        let lines = content.components(separatedBy: .newlines)
        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            var line = rawLine

            if line.contains("/*") { blockCommentDepth += 1 }
            if blockCommentDepth > 0 {
                if line.contains("*/") { blockCommentDepth = max(0, blockCommentDepth - 1) }
                continue
            }

            if let commentStart = line.range(of: "//") {
                line = String(line[..<commentStart.lowerBound])
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if previewBraceBalance == 0, trimmed.hasPrefix("#Preview") {
                previewBraceBalance += braceDelta(in: line)
                continue
            }
            if previewBraceBalance > 0 {
                previewBraceBalance += braceDelta(in: line)
                continue
            }

            if trimmed.isEmpty { continue }

            violations.append(
                contentsOf: lineViolations(in: line, relativePath: relative, lineNumber: lineNumber)
            )
        }

        return violations
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

    private static func lineViolations(
        in line: String,
        relativePath: String,
        lineNumber: Int
    ) -> [HardcodedColorViolation] {
        guard !isExplicitlyAllowedContext(line) else { return [] }

        var found: [HardcodedColorViolation] = []
        for pattern in literalPatterns {
            for match in pattern.matches(in: line) {
                found.append(
                    HardcodedColorViolation(
                        relativePath: relativePath,
                        line: lineNumber,
                        matchedPattern: match.pattern,
                        lineContent: line
                    )
                )
            }
        }
        return found
    }

    private static func isExplicitlyAllowedContext(_ line: String) -> Bool {
        let allowances = [
            #"case\s+\.(oceanBlue|blossomPink|emeraldGreen|sunsetOrange)\b"#,
            #"palette:\s*\.(oceanBlue|blossomPink|emeraldGreen|sunsetOrange)\b"#,
            #"AppThemePalette\.(oceanBlue|blossomPink|emeraldGreen|sunsetOrange)\b"#,
            #"appearance:\s*\.(oceanBlue|blossomPink|emeraldGreen|sunsetOrange)\b"#,
            #"\.whitespaces"#,
            #"\.whitespacesAndNewlines"#,
            #"\.reduce\b"#,
            #"rgba\.(red|green|blue)\b"#,
            #"components\.(red|green|blue)\b"#,
            #"\b[ab]\.(red|green|blue)\b"#,
            #"channel\(rgba\.(red|green|blue)\)"#,
            #"delta(Red|Green|Blue)\b"#,
            #"redactedUID"#,
            #"AuthState\.failed"#,
            #"Color\.clear\b"#,
            #"\.clear\b"#,
            #"UIColor\(FormaTokens"#,
            #"UIColor\(color\)"#
        ]

        return allowances.contains { line.range(of: $0, options: .regularExpression) != nil }
    }

    private struct PatternMatch {
        let pattern: String
        let range: Range<String.Index>
    }

    private struct LiteralPattern {
        let name: String
        let regex: NSRegularExpression

        func matches(in line: String) -> [PatternMatch] {
            let nsRange = NSRange(line.startIndex..., in: line)
            return regex.matches(in: line, range: nsRange).compactMap { result in
                guard let range = Range(result.range, in: line) else { return nil }
                return PatternMatch(pattern: name, range: range)
            }
        }
    }

    private static let literalPatterns: [LiteralPattern] = {
        let colors = disallowedSystemColorNames.joined(separator: "|")
        let specs: [(String, String)] = [
            ("SwiftUI system color (\\.color)", "\\.(?:\(colors))\\b"),
            ("SwiftUI Color.*", "Color\\.(?:\(colors))\\b"),
            ("Color(red:", "Color\\s*\\(\\s*red\\s*:"),
            ("Color(hue:", "Color\\s*\\(\\s*hue\\s*:"),
            ("Color(white:", "Color\\s*\\(\\s*white\\s*:"),
            ("UIColor system", "UIColor\\.(?:system[A-Za-z]+|(?:\(colors)))\\b"),
            ("UIColor(red:", "UIColor\\s*\\(\\s*red\\s*:"),
            ("Hex color helper", "(?:Color|UIColor)\\s*\\(\\s*hex"),
            ("Color hex literal", "Color\\s*\\(\\s*#")
        ]

        return specs.compactMap { name, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return LiteralPattern(name: name, regex: regex)
        }
    }()
}
