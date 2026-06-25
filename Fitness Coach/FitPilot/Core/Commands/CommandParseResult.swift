//
//  CommandParseResult.swift
//  Fitness Coach
//
//  FitPilot AI — Result of attempting to parse a local command.
//
//  The parser never throws for normal parse failures. It returns one of these
//  structured outcomes instead.
//

import Foundation

enum CommandParseResult: Equatable, Sendable {
    /// The parser confidently understood the command.
    case success(ParsedCommand)

    /// The command is outside the current local parsing scope.
    case unsupported(originalText: String, reason: String?)

    /// The intent is likely valid but requires AI interpretation later.
    case needsAI(originalText: String, reason: String?)

    /// The command was recognized but contained invalid values.
    case invalid(originalText: String, reason: String)

    /// There were too many possible interpretations to choose safely.
    case ambiguous(originalText: String, reason: String)
}
