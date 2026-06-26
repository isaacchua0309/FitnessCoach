//
//  PipelineTracerTests.swift
//  Fitness CoachTests
//
//  Pipeline trace logging regression tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PipelineTracerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        FitPilotPipelineTracer.clear()
    }

    func testBeginAndEndTraceCreatesSummary() {
        let traceId = FitPilotPipelineTracer.beginTrace(userMessage: "log 2 eggs")
        FitPilotPipelineTracer.endTrace(traceId: traceId, outcome: "ok", durationMs: 12)

        let summary = FitPilotPipelineTracer.recentSummaries.first { $0.traceId == traceId }
        XCTAssertEqual(summary?.userMessage, "log 2 eggs")
        XCTAssertEqual(summary?.outcome, "ok")
        XCTAssertFalse(summary?.hasError ?? true)
    }

    func testRingBufferCapsEventCount() {
        for index in 0..<305 {
            let traceId = FitPilotPipelineTracer.beginTrace(userMessage: "message \(index)")
            FitPilotPipelineTracer.event(
                traceId: traceId,
                stage: .localGuard,
                message: "event \(index)"
            )
            FitPilotPipelineTracer.endTrace(traceId: traceId, outcome: "ok")
        }

        XCTAssertLessThanOrEqual(FitPilotPipelineTracer.recentEvents.count, 300)
    }

    func testErrorMarksSummaryAsFailed() {
        let traceId = FitPilotPipelineTracer.beginTrace(userMessage: "broken")
        FitPilotPipelineTracer.logError(
            traceId: traceId,
            stage: .httpResponse,
            message: "HTTP failed",
            fields: ["status": "500"]
        )
        FitPilotPipelineTracer.endTrace(traceId: traceId, outcome: "error")

        let summary = FitPilotPipelineTracer.recentSummaries.first { $0.traceId == traceId }
        XCTAssertTrue(summary?.hasError ?? false)
    }

    func testSanitizedJSONSnippetHiddenWhenNotVerbose() {
        let data = Data("{\"text\":\"hello\"}".utf8)
        XCTAssertNil(FitPilotPipelineTracer.sanitizedJSONSnippet(data))
    }

    func testExportTraceIncludesEvents() {
        let traceId = FitPilotPipelineTracer.beginTrace(userMessage: "export me")
        FitPilotPipelineTracer.event(traceId: traceId, stage: .classify, message: "classified")
        FitPilotPipelineTracer.endTrace(traceId: traceId, outcome: "ok")

        let exported = FitPilotPipelineTracer.exportTrace(traceId: traceId)
        XCTAssertTrue(exported.contains(traceId.uuidString))
        XCTAssertTrue(exported.contains("export me"))
        XCTAssertTrue(exported.contains("classified"))
    }

    func testTaskLocalTraceIdUsedByBackendClient() async throws {
        TraceHeaderURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TraceHeaderURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let traceId = FitPilotPipelineTracer.beginTrace(userMessage: "header test")
        let client = FitPilotAIBackendClient(
            baseURL: URL(string: "http://trace.test")!,
            urlSession: session
        )

        let request = AICoachIntentClassificationRequest(
            text: "hello",
            context: AIContext(date: Date(timeIntervalSince1970: 0), timezoneIdentifier: "UTC"),
            modelName: CoachModelConfig.default.cheapClassifierModel,
            modelConfig: .default
        )

        do {
            _ = try await client.classifyCoachIntent(request: request)
        } catch {
            // Decoding may fail on stub body; header assertion is the goal.
        }

        XCTAssertEqual(
            TraceHeaderURLProtocol.lastTraceHeader,
            traceId.uuidString
        )
    }
}

private final class TraceHeaderURLProtocol: URLProtocol {

    static var lastTraceHeader: String?

    static func reset() {
        lastTraceHeader = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastTraceHeader = request.value(forHTTPHeaderField: FitPilotPipelineTracer.traceHeaderName)

        let payload = """
        {"intentResult":{"intent":"general_conversation","confidence":1,"domain":"general","requiresAppMutation":false,"requiresUserContext":false,"canAnswerWithCheapModel":true,"requiresEscalation":false,"entities":{"food":null,"meal":null,"amountMl":null,"weightKg":null,"durationMinutes":null,"distanceKm":null,"calories":null,"proteinGrams":null,"carbsGrams":null,"fatGrams":null,"quantity":null,"unit":null,"notes":null},"action":null,"reason":null}}
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
