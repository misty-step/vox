import XCTest
@testable import VoxCore

final class MultipartFormDataTests: XCTestCase {
    func test_addField_producesExpectedFormat() {
        var form = MultipartFormData(boundary: "test.boundary")
        form.addField(name: "title", value: "hello")

        let data = form.finalize()
        let expected = "--test.boundary\r\n" +
            "Content-Disposition: form-data; name=\"title\"\r\n\r\n" +
            "hello\r\n" +
            "--test.boundary--\r\n"

        XCTAssertEqual(utf8String(data), expected)
    }

    func test_addFile_producesExpectedFormatWithContentType() {
        var form = MultipartFormData(boundary: "test.boundary")
        form.addFile(
            name: "file",
            filename: "note.txt",
            mimeType: "text/plain",
            data: Data("payload".utf8)
        )

        let data = form.finalize()
        let expected = "--test.boundary\r\n" +
            "Content-Disposition: form-data; name=\"file\"; filename=\"note.txt\"\r\n" +
            "Content-Type: text/plain\r\n\r\n" +
            "payload\r\n" +
            "--test.boundary--\r\n"

        XCTAssertEqual(utf8String(data), expected)
    }

    func test_finalize_addsClosingBoundary() {
        var form = MultipartFormData(boundary: "test.boundary")

        let data = form.finalize()

        XCTAssertEqual(utf8String(data), "--test.boundary--\r\n")
    }

    func test_multipleFieldsAndFiles_appendInOrder() {
        var form = MultipartFormData(boundary: "test.boundary")
        form.addField(name: "one", value: "1")
        form.addField(name: "two", value: "2")
        form.addFile(
            name: "file",
            filename: "data.bin",
            mimeType: "application/octet-stream",
            data: Data("bin".utf8)
        )

        let data = form.finalize()
        let expected = "--test.boundary\r\n" +
            "Content-Disposition: form-data; name=\"one\"\r\n\r\n" +
            "1\r\n" +
            "--test.boundary\r\n" +
            "Content-Disposition: form-data; name=\"two\"\r\n\r\n" +
            "2\r\n" +
            "--test.boundary\r\n" +
            "Content-Disposition: form-data; name=\"file\"; filename=\"data.bin\"\r\n" +
            "Content-Type: application/octet-stream\r\n\r\n" +
            "bin\r\n" +
            "--test.boundary--\r\n"

        XCTAssertEqual(utf8String(data), expected)
    }

    func test_boundary_includedInOutput() {
        var form = MultipartFormData(boundary: "custom.boundary")
        form.addField(name: "key", value: "value")

        let data = form.finalize()

        XCTAssertTrue(utf8String(data).contains("custom.boundary"))
    }

    func test_customBoundary_isUsed() {
        var form = MultipartFormData(boundary: "custom.boundary")
        form.addField(name: "key", value: "value")

        let data = form.finalize()

        XCTAssertTrue(utf8String(data).hasPrefix("--custom.boundary\r\n"))
        XCTAssertTrue(utf8String(data).hasSuffix("--custom.boundary--\r\n"))
    }

    private func utf8String(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }
}
