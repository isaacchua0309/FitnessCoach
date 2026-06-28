//
//  ForcedDarkAppearanceGuard.swift
//  Fitness CoachTests
//
//  Forma — Scans production Swift for hard-forced dark appearance overrides.
//

import Foundation

struct ForcedDarkAppearanceViolation: Equatable {
    let relativePath: String
    let line: Int
    let lineContent: String

    var diagnosticMessage: String {
        """
        \(relativePath):\(line) — forced `.preferredColorScheme(.dark)`
          \(lineContent.trimmingCharacters(in: .whitespaces))
          Suggested fix: remove this modifier and rely on root `FormaRootThemeModifier` + `ThemeStore`, or use `.formaThemePreview()` in `#Preview` blocks only.
        """
    }
}

enum ForcedDarkAppearanceGuard {

    static let scannedSourceDirectory = "Fitness Coach"
    static let pattern = ".preferredColorScheme(.dark)"

    static let approvedRelativePaths: Set<String> = [
        "Fitness Coach/DesignSystem/Theme/FormaThemeScreenModifier.swift",
        "Fitness Coach/DesignSystem/Theme/FormaThemeEnvironment.swift"
    ]

    static let approvedFileNameSuffixes = [
        "PreviewScreens.swift"
    ]

    static func scan(repositoryRoot: URL) -> [ForcedDarkAppearanceViolation] {
        let sourceRoot = repositoryRoot.appendingPathComponent(scannedSourceDirectory, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var violations: [ForcedDarkAppearanceViolation] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let relative = relativePath(for: fileURL, repositoryRoot: repositoryRoot)
            if isExcluded(relativePath: relative, fileName: fileURL.lastPathComponent) { continue }
            violations.append(contentsOf: scanFile(at: fileURL, relativePath: relative))
        }

        return violations.sorted {
            $0.relativePath == $1.relativePath ? $0.line < $1.line : $0.relativePath < $1.relativePath
        }
    }

    private static func isExcluded(relativePath: String, fileName: String) -> Bool {
        if relativePath.contains("/Fitness CoachTests/") { return true }
        if approvedRelativePaths.contains(relativePath) { return true }
        if approvedFileNameSuffixes.contains(where: { fileName.hasSuffix($0) }) { return true }
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

    private static func scanFile(at url: URL, relativePath: String) -> [ForcedDarkAppearanceViolation] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var violations: [ForcedDarkAppearanceViolation] = []
        var blockCommentDepth = 0
        var previewBraceBalance = 0

        for (index, rawLine) in content.components(separatedBy: .newlines).enumerated() {
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

            if line.contains(pattern) {
                violations.append(
                    ForcedDarkAppearanceViolation(
                        relativePath: relativePath,
                        line: lineNumber,
                        lineContent: line
                    )
                )
            }
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
}
