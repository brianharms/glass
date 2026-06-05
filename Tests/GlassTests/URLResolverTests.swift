import XCTest
@testable import GlassKit

final class URLResolverTests: XCTestCase {
    func testHTTPURL() {
        let result = URLResolver.resolve("http://localhost:3000")
        guard case .web(let url) = result else {
            return XCTFail("Expected .web, got \(String(describing: result))")
        }
        XCTAssertEqual(url.absoluteString, "http://localhost:3000")
    }

    func testHTTPSURL() {
        let result = URLResolver.resolve("https://example.com/page")
        guard case .web(let url) = result else {
            return XCTFail("Expected .web, got \(String(describing: result))")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/page")
    }

    func testAbsoluteFilePath() throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("glass-test-\(UUID().uuidString).html")
        try "hello".write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let result = URLResolver.resolve(tmpFile.path)
        guard case .file(let url) = result else {
            return XCTFail("Expected .file, got \(String(describing: result))")
        }
        XCTAssertEqual(url.path, tmpFile.path)
    }

    func testNonexistentFileReturnsNil() {
        let result = URLResolver.resolve("/tmp/does-not-exist-glass-test.html")
        XCTAssertNil(result)
    }

    func testEmptyStringReturnsNil() {
        let result = URLResolver.resolve("")
        XCTAssertNil(result)
    }

    func testRelativeFilePath() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let tmpFile = URL(fileURLWithPath: cwd).appendingPathComponent("glass-test-\(UUID().uuidString).html")
        try "hello".write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let result = URLResolver.resolve(tmpFile.lastPathComponent)
        guard case .file(let url) = result else {
            return XCTFail("Expected .file, got \(String(describing: result))")
        }
        XCTAssertTrue(url.path.hasSuffix(tmpFile.lastPathComponent))
    }
}
