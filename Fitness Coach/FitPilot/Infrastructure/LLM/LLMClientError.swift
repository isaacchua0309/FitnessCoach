//
//  LLMClientError.swift
//  Fitness Coach
//
//  FitPilot AI — Errors produced by the LLM client boundary.
//

import Foundation

enum LLMClientError: Error, Equatable {
    case invalidURL
    case requestFailed(String)
    case invalidStatusCode(Int)
    case decodingFailed(String)
    case missingConfiguration
}
