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
        FormaPipelineTracer.clear()
    }

    func testBeginAndEndTraceCreatesSummary() {
        let traceId = FormaPipelineTracer.beginTrace(userMessage: "log 2 eggs")
        FormaPipelineTracer.endTrace(traceId: traceId, outcome: "ok", durationMs: 12)

        let summary = FormaPipelineTracer.recentSummaries.first { $0.traceId == traceId }
        XCTAssertEqual(summary?.userMessage, "log 2 eggs")
        XCTAssertEqual(summary?.outcome, "ok")
        XCTAssertFalse(summary?.hasError ?? true)
    }

    func testRingBufferCapsEventCount() {
        for index in 0..<305 {
            let traceId = FormaPipelineTracer.beginTrace(userMessage: "message \(index)")
            FormaPipelineTracer.event(
                traceId: traceId,
                stage: .localGuard,
                message: "event \(index)"
            )
            FormaPipelineTracer.endTrace(traceId: traceId, outcome: "ok")
        }

        XCTAssertLessThanOrEqual(FormaPipelineTracer.recentEvents.count, 300)
    }

    func testErrorMarksSummaryAsFailed() {
        let traceId = FormaPipelineTracer.beginTrace(userMessage: "broken")
        FormaPipelineTracer.logError(
            traceId: traceId,
            stage: .httpResponse,
            message: "HTTP failed",
            fields: ["status": "500"]
        )
        FormaPipelineTracer.endTrace(traceId: traceId, outcome: "error")

        let summary = FormaPipelineTracer.recentSummaries.first { $0.traceId == traceId }
        XCTAssertTrue(summary?.hasError ?? false)
    }

    func testSanitizedJSONSnippetHiddenWhenNotVerbose() {
        let data = Data("{\"text\":\"hello\"}".utf8)
        XCTAssertNil(FormaPipelineTracer.sanitizedJSONSnippet(data))
    }

    func testExportTraceIncludesEvents() {
        let traceId = FormaPipelineTracer.beginTrace(userMessage: "export me")
        FormaPipelineTracer.event(traceId: traceId, stage: .classify, message: "classified")
        FormaPipelineTracer.endTrace(traceId: traceId, outcome: "ok")

        let exported = FormaPipelineTracer.exportTrace(traceId: traceId)
        XCTAssertTrue(exported.contains(traceId.uuidString))
        XCTAssertTrue(exported.contains("export me"))
        XCTAssertTrue(exported.contains("classified"))
    }

    func testTaskLocalTraceIdUsedByBackendClient() async throws {
        TraceHeaderURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TraceHeaderURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let traceId = FormaPipelineTracer.beginTrace(userMessage: "header test")
        let client = FormaAIBackendClient(
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
        Self.lastTraceHeader = request.value(forHTTPHeaderField: FormaPipelineTracer.traceHeaderName)

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
