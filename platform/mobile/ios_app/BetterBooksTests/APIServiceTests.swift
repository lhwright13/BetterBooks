import XCTest
@testable import BetterBooks

final class APIServiceTests: XCTestCase {

    var apiService: APIService!

    override func setUp() async throws {
        apiService = APIService()
    }

    // MARK: - URL Construction Tests

    func testAudioStreamURLConstruction() async {
        let url = await apiService.audioStreamURL(bookTitle: "The Great Gatsby", chapter: 3)

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("The%20Great%20Gatsby"))
        XCTAssertTrue(url!.absoluteString.contains("Chapter%203.mp3"))
    }

    func testAudioStreamURLWithSpecialCharacters() async {
        let url = await apiService.audioStreamURL(bookTitle: "Alice's Adventures", chapter: 1)

        XCTAssertNotNil(url)
        // URL should be properly encoded
        XCTAssertTrue(url!.absoluteString.contains("Alice"))
    }

    // MARK: - Auth Token Tests

    func testSetAuthToken() async {
        await apiService.setAuthToken("test-token-123")
        // Token is private, but we can test that it doesn't crash
        // In a real test, we'd verify the token is used in requests
    }

    func testSetAuthTokenNil() async {
        await apiService.setAuthToken(nil)
        // Should handle nil gracefully
    }
}

// MARK: - Mock URLProtocol for Network Tests

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Request handler not set")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
