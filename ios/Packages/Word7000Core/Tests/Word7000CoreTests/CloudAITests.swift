import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import Word7000Core

final class CloudAITests: XCTestCase {
    final class FakeTransport: HTTPTransport, @unchecked Sendable {
        var responses: [(String, Int)]
        var requests: [URLRequest] = []
        init(_ responses: [(String, Int)]) { self.responses = responses }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let (body, status) = responses.removeFirst()
            return (Data(body.utf8), status)
        }
    }

    let config = SupabaseConfig(url: "https://abcdefgh.supabase.co", key: "sb_publishable_x")!
    let session = try! JSONDecoder().decode(AuthSession.self, from: Data(
        #"{"access_token":"a1","refresh_token":"r1","expires_in":3600,"user":{"id":"u1","is_anonymous":true}}"#.utf8))

    func testSendsTheTaskWithTheLearnersSessionAndDecodesTheResult() async throws {
        let transport = FakeTransport([(#"{"result":{"explanation":"run 是跑","memoryTip":"想像跑步"},"model":"openai/gpt-oss-20b"}"#, 200)])
        let reply = try await SupabaseClient(config: config, transport: transport)
            .runAI(.quizWhy, input: ["word": .string("run")], session: session, as: CloudAI.QuizExplanation.self)
        XCTAssertEqual(reply, CloudAI.QuizExplanation(explanation: "run 是跑", memoryTip: "想像跑步"))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://abcdefgh.supabase.co/functions/v1/ai")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer a1")
        XCTAssertEqual(request.timeoutInterval, CloudAI.timeout)
        let body = try JSONDecoder().decode([String: JSONValue].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body["task"], .string("quizWhy"))
        XCTAssertEqual(body["input"], .object(["word": .string("run")]))
    }

    func testCoachFeedbackDecodesFromTheServerShape() async throws {
        let json = #"{"result":{"rewrite":"I practice every day.","tip":"很好","followUp":"Why?","corrections":[{"original":"everyday","replacement":"every day","reason":"副詞要分開"}]}}"#
        let feedback = try await SupabaseClient(config: config, transport: FakeTransport([(json, 200)]))
            .runAI(.coach, input: [:], session: session, as: SpeakingCoach.Feedback.self)
        XCTAssertEqual(feedback.corrections.first?.replacement, "every day")
    }

    func testSendsThePlusProofAndReportsTodaysUsage() async throws {
        let transport = FakeTransport([(#"{"result":{"explanation":"x","memoryTip":"y"},"model":"openai/gpt-oss-120b","tier":"plus","limit":100,"remaining":87}"#, 200)])
        let reply = try await SupabaseClient(config: config, transport: transport)
            .runAI(.quizWhy, input: [:], session: session, entitlement: "header.payload.sig", as: CloudAI.QuizExplanation.self)
        XCTAssertEqual(reply.usage, CloudAI.Usage(tier: .plus, limit: 100, remaining: 87))
        XCTAssertTrue(reply.usage?.tier.usesStrongestModel == true)
        let body = try JSONDecoder().decode([String: JSONValue].self, from: XCTUnwrap(transport.requests.first?.httpBody))
        XCTAssertEqual(body["entitlement"], .string("header.payload.sig"))
    }

    func testOlderRepliesWithoutUsageStillDecode() async throws {
        let reply = try await SupabaseClient(config: config, transport: FakeTransport([(#"{"result":{"explanation":"x","memoryTip":"y"}}"#, 200)]))
            .runAI(.quizWhy, input: [:], session: session, entitlement: nil, as: CloudAI.QuizExplanation.self)
        XCTAssertNil(reply.usage)
        XCTAssertFalse(CloudAI.Tier.free.usesStrongestModel)
    }

    func testMapsServerErrorsToFallbackDecisions() async {
        let cases: [(String, Int, CloudAI.Failure)] = [
            (#"{"error":"quota"}"#, 429, .quota),
            (#"{"error":"busy","retryAfter":3}"#, 429, .busy),
            (#"{"error":"invalid_input"}"#, 400, .invalidInput),
            (#"{"error":"unauthorized"}"#, 401, .signInRequired),
            (#"{"error":"unavailable"}"#, 503, .unavailable),
            ("not json", 502, .unavailable),
            (#"{"unexpected":true}"#, 200, .unavailable),
        ]
        for (body, status, expected) in cases {
            do {
                _ = try await SupabaseClient(config: config, transport: FakeTransport([(body, status)]))
                    .runAI(.explain, input: [:], session: session, as: CloudAI.Explanation.self)
                XCTFail("\(status) should fail")
            } catch {
                XCTAssertEqual(error as? CloudAI.Failure, expected, body)
            }
        }
    }

    func testCleaningCapsListsAndRejectsAnEmptyExplanation() throws {
        let long = String(repeating: "字", count: 500)
        let explanation = CloudAI.Explanation(summary: " 意思 ", usage: long, collocations: ["a", "", "b", "c", "d", "e", "f"],
                                              examples: (0..<5).map { .init(sentence: "S\($0)", translation: "T\($0)") } + [.init(sentence: " ", translation: "x")],
                                              pitfall: "", memoryTip: "")
        let cleaned = try explanation.cleaned()
        XCTAssertEqual(cleaned.summary, "意思")
        XCTAssertEqual(cleaned.usage.count, 360)
        XCTAssertEqual(cleaned.collocations, ["a", "b", "c", "d", "e"])
        XCTAssertEqual(cleaned.examples.count, 3)
        XCTAssertThrowsError(try CloudAI.Explanation(summary: " ", usage: "", collocations: [], examples: [], pitfall: "", memoryTip: "").cleaned())
        XCTAssertThrowsError(try CloudAI.QuizExplanation(explanation: "", memoryTip: "x").cleaned())
    }
}
