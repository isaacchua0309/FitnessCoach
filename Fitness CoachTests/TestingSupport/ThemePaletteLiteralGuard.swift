//
//  ThemePaletteLiteralGuard.swift
//  Fitness CoachTests
//
//  Forma — Flags blue/pink palette literals in reusable UI outside theme definitions.
//

import Foundation

struct ThemePaletteLiteralViolation: Equatable {
  let relativePath: String
  let line: Int
  let matchedPattern: String
  let lineContent: String

  var diagnosticMessage: String {
    """
    \(relativePath):\(line) — matched `\(matchedPattern)`
      \(lineContent.trimmingCharacters(in: .whitespaces))
      Suggested fix: use `@Environment(\\.theme)` semantic tokens or `ThemeManager.selectedTheme`, not raw blue/pink literals.
    """
  }
}

enum ThemePaletteLiteralGuard {

  static let scannedSourceDirectory = "Fitness Coach"

  /// Paths where palette literals must not appear (reusable UI).
  static let reusableUIPathPrefixes = [
    "Fitness Coach/Features/",
    "Fitness Coach/DesignSystem/Components/",
    "Fitness Coach/DesignSystem/Legacy/",
    "Fitness Coach/App/"
  ]

  /// Theme token definition sources may contain raw palette values.
  static let themeDefinitionPathPrefix = "Fitness Coach/DesignSystem/Theme/"

  static func scan(repositoryRoot: URL) -> [ThemePaletteLiteralViolation] {
    let sourceRoot = repositoryRoot.appendingPathComponent(scannedSourceDirectory, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
      at: sourceRoot,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var violations: [ThemePaletteLiteralViolation] = []
    for case let fileURL as URL in enumerator {
      guard fileURL.pathExtension == "swift" else { continue }
      guard shouldScan(path: fileURL, repositoryRoot: repositoryRoot) else { continue }
      violations.append(contentsOf: scanFile(at: fileURL, repositoryRoot: repositoryRoot))
    }

    return violations.sorted {
      $0.relativePath == $1.relativePath
        ? $0.line < $1.line
        : $0.relativePath < $1.relativePath
    }
  }

  private static func shouldScan(path: URL, repositoryRoot: URL) -> Bool {
    let relative = relativePath(for: path, repositoryRoot: repositoryRoot)
    if relative.hasPrefix(themeDefinitionPathPrefix) { return false }
    if relative.contains("/Fitness CoachTests/") { return false }
    return reusableUIPathPrefixes.contains { relative.hasPrefix($0) }
  }

  private static func relativePath(for url: URL, repositoryRoot: URL) -> String {
    let root = repositoryRoot.standardizedFileURL.path
    let full = url.standardizedFileURL.path
    if full.hasPrefix(root + "/") {
      return String(full.dropFirst(root.count + 1))
    }
    return full
  }

  private static func scanFile(at url: URL, repositoryRoot: URL) -> [ThemePaletteLiteralViolation] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    let relative = relativePath(for: url, repositoryRoot: repositoryRoot)
    var violations: [ThemePaletteLiteralViolation] = []
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

      for pattern in literalPatterns {
        if pattern.regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
          violations.append(
            ThemePaletteLiteralViolation(
              relativePath: relative,
              line: lineNumber,
              matchedPattern: pattern.name,
              lineContent: line
            )
          )
        }
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

  private struct LiteralPattern {
    let name: String
    let regex: NSRegularExpression
  }

  private static let literalPatterns: [LiteralPattern] = {
    let specs: [(String, String)] = [
      ("SwiftUI .blue", #"\.blue\b"#),
      ("SwiftUI .pink", #"\.pink\b"#),
      ("Color.blue", #"\bColor\.blue\b"#),
      ("Color.pink", #"\bColor\.pink\b"#),
      ("Named Color(\"Blue\")", #"Color\s*\(\s*\"Blue\"\s*\)"#),
      ("Named Color(\"Pink\")", #"Color\s*\(\s*\"Pink\"\s*\)"#),
      ("formaBlue token", #"\bformaBlue\b"#),
      ("formaPink token", #"\bformaPink\b"#)
    ]

    return specs.compactMap { name, pattern in
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
      return LiteralPattern(name: name, regex: regex)
    }
  }()
}
