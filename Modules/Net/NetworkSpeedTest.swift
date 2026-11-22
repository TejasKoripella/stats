import Foundation

enum NetworkSpeedTest {
    static let resultKey = "Network_speedTestResult"

    struct Result: Codable {
        let downloadBytesPerSecond: Int64
        let uploadBytesPerSecond: Int64

        private struct Throughput: Decodable {
            let dl_throughput: Double
            let ul_throughput: Double
        }

        init(data: Data) throws {
            let throughput = try JSONDecoder().decode(Throughput.self, from: data)
            self.downloadBytesPerSecond = try Self.bytesPerSecond(throughput.dl_throughput)
            self.uploadBytesPerSecond = try Self.bytesPerSecond(throughput.ul_throughput)
        }

        private static func bytesPerSecond(_ bitsPerSecond: Double) throws -> Int64 {
            guard let bytes = Int64(exactly: (bitsPerSecond / 8).rounded()), bytes > 0 else {
                throw TestError.invalidThroughput
            }
            return bytes
        }
    }

    private enum TestError: Error {
        case commandFailed
        case invalidThroughput
    }

    static func run(interface: String) throws -> Result {
        let process = Process()
        let output = Pipe()
        var arguments = ["-s"]
        if !interface.isEmpty {
            arguments += ["-I", interface]
        }
        arguments.append("-c")

        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationReason == .exit && process.terminationStatus == 0 else {
            throw TestError.commandFailed
        }
        return try Result(data: data)
    }
}
