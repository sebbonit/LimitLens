import Foundation

public protocol DesktopQuotaFetching: Sendable {
    func fetchSnapshots() async throws -> [DesktopQuotaSnapshot]
}

public final class DesktopQuotaClient: DesktopQuotaFetching, @unchecked Sendable {
    private let sources: [DesktopQuotaSource]
    private let liveDatabasePath: String

    public init(
        sources: [DesktopQuotaSource] = [
            DesktopQuotaSource(
                appName: "Devin Desktop",
                databasePath: "\(NSHomeDirectory())/Library/Application Support/Devin/User/globalStorage/state.vscdb",
                keyQueries: [
                    "SELECT value FROM ItemTable WHERE key='windsurfAuthStatus' LIMIT 1;",
                    "SELECT value FROM ItemTable WHERE key LIKE 'windsurf.reactSettings.cachedPlanInfoData:%' ORDER BY key LIMIT 1;",
                    "SELECT value FROM ItemTable WHERE key='windsurf.settings.cachedPlanInfo' LIMIT 1;"
                ]
            )
        ],
        liveDatabasePath: String? = nil
    ) {
        self.sources = sources
        self.liveDatabasePath = liveDatabasePath ?? sources.first?.databasePath ?? "\(NSHomeDirectory())/Library/Application Support/Devin/User/globalStorage/state.vscdb"
    }

    public func fetchSnapshots() async throws -> [DesktopQuotaSnapshot] {
        let sources = self.sources
        let liveDatabasePath = self.liveDatabasePath
        return try await Task.detached(priority: .utility) {
            if let remoteSnapshot = try? await DevinRemoteQuotaClient(databasePath: liveDatabasePath).fetchSnapshot() {
                return [remoteSnapshot]
            }
            try Task.checkCancellation()

            if let liveSnapshot = try? await DevinLanguageServerQuotaClient(databasePath: liveDatabasePath).fetchSnapshot() {
                return [liveSnapshot]
            }
            try Task.checkCancellation()

            return try sources.compactMap { source -> DesktopQuotaSnapshot? in
                guard FileManager.default.fileExists(atPath: source.databasePath) else {
                    return nil
                }
                guard let raw = try source.firstPlanInfoJSON() else {
                    return nil
                }
                guard let data = raw.data(using: .utf8) else {
                    return nil
                }
                if let authStatus = try? JSONDecoder().decode(DesktopQuotaAuthStatus.self, from: data),
                   let snapshot = authStatus.snapshot(appName: source.appName, isStaleFallback: true) {
                    return snapshot
                }
                let plan = try JSONDecoder().decode(DesktopQuotaPlanInfo.self, from: data)
                return plan.snapshot(appName: source.appName, isStaleFallback: true)
            }
        }.value
    }
}

private final class DevinRemoteQuotaClient: @unchecked Sendable {
    private let databasePath: String
    private let endpoint: URL

    init(
        databasePath: String = "\(NSHomeDirectory())/Library/Application Support/Devin/User/globalStorage/state.vscdb",
        endpoint: URL = URL(string: "https://server.codeium.com/exa.seat_management_pb.SeatManagementService/GetUserStatus")!
    ) {
        self.databasePath = databasePath
        self.endpoint = endpoint
    }

    func fetchSnapshot() async throws -> DesktopQuotaSnapshot {
        let auth = try DevinAuthStatusReader(databasePath: databasePath).read()
        let request = MinimalProtobufWriter.message(1, auth.metadata)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = request
        urlRequest.timeoutInterval = 8
        urlRequest.setValue("application/proto", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/proto", forHTTPHeaderField: "Accept")
        urlRequest.setValue("1", forHTTPHeaderField: "connect-protocol-version")
        if let apiKey = auth.apiKey, !apiKey.isEmpty {
            urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CodexUsageError.unavailable("Devin quota is temporarily unavailable.")
        }

        return try DevinUserStatusSnapshotDecoder.decode(data)
    }
}

private final class DevinLanguageServerQuotaClient: @unchecked Sendable {
    private let databasePath: String

    init(databasePath: String = "\(NSHomeDirectory())/Library/Application Support/Devin/User/globalStorage/state.vscdb") {
        self.databasePath = databasePath
    }

    func fetchSnapshot() async throws -> DesktopQuotaSnapshot {
        let auth = try DevinAuthStatusReader(databasePath: databasePath).read()
        let process = try DevinLanguageServerProcess.current()
        let request = MinimalProtobufWriter.message(1, auth.metadata)

        var urlRequest = URLRequest(url: URL(string: "http://127.0.0.1:\(process.port)/exa.language_server_pb.LanguageServerService/GetUserStatus")!)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = request
        urlRequest.timeoutInterval = 5
        urlRequest.setValue("application/proto", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/proto", forHTTPHeaderField: "Accept")
        urlRequest.setValue("1", forHTTPHeaderField: "connect-protocol-version")
        urlRequest.setValue(process.csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CodexUsageError.unavailable("Devin quota is temporarily unavailable.")
        }
        return try DevinUserStatusSnapshotDecoder.decode(data)
    }
}

private enum DevinUserStatusSnapshotDecoder {
    static func decode(_ data: Data) throws -> DesktopQuotaSnapshot {
        guard let responseMessage = MinimalProtobufMessage(data: data),
              let userStatus = responseMessage.message(field: 1),
              let planStatus = userStatus.message(field: 13) else {
            throw CodexUsageError.unavailable("Devin quota response changed.")
        }

        let planInfo = planStatus.message(field: 1)
        return DesktopQuotaSnapshot(
            appName: "Devin Desktop",
            planName: planInfo?.string(field: 2),
            billingStrategy: (planInfo?.varint(field: 35) == 2) ? "quota" : nil,
            cycleStart: planStatus.timestamp(field: 2),
            cycleEnd: planStatus.timestamp(field: 3),
            dailyRemainingPercent: planStatus.int(field: 14),
            weeklyRemainingPercent: planStatus.int(field: 15),
            dailyResetAt: planStatus.unixDate(field: 17),
            weeklyResetAt: planStatus.unixDate(field: 18),
            overageBalanceMicros: planStatus.signedInt64(field: 16)
        )
    }
}

private struct DevinAuthStatusReader {
    let databasePath: String

    func read() throws -> DesktopQuotaAuthStatus {
        let source = DesktopQuotaSource(
            appName: "Devin Desktop",
            databasePath: databasePath,
            keyQueries: ["SELECT value FROM ItemTable WHERE key='windsurfAuthStatus' LIMIT 1;"]
        )
        guard let raw = try source.firstPlanInfoJSON(),
              let data = raw.data(using: .utf8) else {
            throw CodexUsageError.unavailable("Devin auth status is unavailable.")
        }
        return try JSONDecoder().decode(DesktopQuotaAuthStatus.self, from: data)
    }
}

private struct DevinLanguageServerProcess {
    let pid: String
    let port: Int
    let csrfToken: String

    static func current() throws -> DevinLanguageServerProcess {
        let processes = shellOutput("/bin/ps", ["axo", "pid=,command="])
        guard let line = processes
            .split(separator: "\n")
            .map(String.init)
            .first(where: { $0.contains("language_server_macos_arm") && $0.contains("--api_server_url") }) else {
            throw CodexUsageError.unavailable("Devin language server is not running.")
        }

        let pid = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        guard !pid.isEmpty else {
            throw CodexUsageError.unavailable("Devin language server pid is unavailable.")
        }

        let env = shellOutput("/bin/ps", ["eww", "-p", pid])
        guard let csrfToken = env
            .split(separator: " ")
            .first(where: { $0.hasPrefix("WINDSURF_CSRF_TOKEN=") })?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init),
            !csrfToken.isEmpty else {
            throw CodexUsageError.unavailable("Devin language server token is unavailable.")
        }

        guard let port = latestLanguageServerPort(pid: pid) ?? listeningPort(pid: pid) else {
            throw CodexUsageError.unavailable("Devin language server port is unavailable.")
        }

        return DevinLanguageServerProcess(pid: pid, port: port, csrfToken: csrfToken)
    }

    private static func latestLanguageServerPort(pid: String) -> Int? {
        let logRoot = "\(NSHomeDirectory())/Library/Application Support/Devin/logs"
        guard let enumerator = FileManager.default.enumerator(atPath: logRoot) else {
            return nil
        }

        var newest: (date: Date, path: String)?
        for case let relativePath as String in enumerator where relativePath.hasSuffix("codeium.windsurf/Devin.log") {
            let path = "\(logRoot)/\(relativePath)"
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let modified = attrs[.modificationDate] as? Date else {
                continue
            }
            if newest == nil || modified > newest!.date {
                newest = (modified, path)
            }
        }

        guard let path = newest?.path else {
            return nil
        }

        let contents = tailOfFile(at: path, maxBytes: 64_000)
        guard !contents.isEmpty else {
            return nil
        }

        let lines = contents.split(separator: "\n").reversed()
        for line in lines where line.contains("Language server listening on random port at") {
            if line.contains(" \(pid) ") || line.contains(" \(pid)]") {
                return line.split(separator: " ").last.flatMap { Int($0) }
            }
            return line.split(separator: " ").last.flatMap { Int($0) }
        }
        return nil
    }

    private static func listeningPort(pid: String) -> Int? {
        let output = shellOutput("/usr/sbin/lsof", ["-nP", "-Pan", "-p", pid, "-iTCP", "-sTCP:LISTEN"])
        let ports = output
            .split(separator: "\n")
            .compactMap { line -> Int? in
                guard let portPart = line.split(separator: " ").last?.split(separator: ":").last else {
                    return nil
                }
                return Int(portPart)
            }
        return ports.min()
    }

    private static func shellOutput(
        _ executable: String,
        _ arguments: [String],
        timeoutSeconds: TimeInterval = 3
    ) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else {
            return ""
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            return ""
        }

        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private static func tailOfFile(at path: String, maxBytes: Int) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return ""
        }
        defer { try? handle.close() }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        if fileSize > maxBytes {
            try? handle.seek(toOffset: UInt64(fileSize - maxBytes))
        }

        let data = handle.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}

public struct DesktopQuotaSource: Sendable {
    public let appName: String
    public let databasePath: String
    public let keyQueries: [String]

    public init(appName: String, databasePath: String, keyQueries: [String]) {
        self.appName = appName
        self.databasePath = databasePath
        self.keyQueries = keyQueries
    }

    func firstPlanInfoJSON() throws -> String? {
        for query in keyQueries {
            let value = try sqliteValue(query: query)
            if let value, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func sqliteValue(query: String) throws -> String? {
        let process = Process()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("resetstat-sqlite-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-cmd", ".timeout 1000", databasePath, query]
        process.standardOutput = outputHandle
        process.standardError = FileHandle.nullDevice

        try process.run()
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        try outputHandle.close()
        let outputData = try Data(contentsOf: outputURL)
        let value = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct DesktopQuotaPlanInfo: Decodable, Equatable {
    let planName: String?
    let billingStrategy: String?
    let startTimestamp: Int64?
    let endTimestamp: Int64?
    let quotaUsage: QuotaUsage?
    let dailyRemainingPercent: Int?
    let weeklyRemainingPercent: Int?
    let dailyResetAtUnix: Int64?
    let weeklyResetAtUnix: Int64?
    let overageBalanceMicros: Int64?

    struct QuotaUsage: Decodable, Equatable {
        let dailyRemainingPercent: Int?
        let weeklyRemainingPercent: Int?
        let dailyResetAtUnix: Int64?
        let weeklyResetAtUnix: Int64?
        let overageBalanceMicros: Int64?
    }

    func snapshot(appName: String, isStaleFallback: Bool = false) -> DesktopQuotaSnapshot {
        DesktopQuotaSnapshot(
            appName: appName,
            planName: planName,
            billingStrategy: billingStrategy,
            cycleStart: startTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            cycleEnd: endTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            dailyRemainingPercent: quotaUsage?.dailyRemainingPercent ?? dailyRemainingPercent,
            weeklyRemainingPercent: quotaUsage?.weeklyRemainingPercent ?? weeklyRemainingPercent,
            dailyResetAt: (quotaUsage?.dailyResetAtUnix ?? dailyResetAtUnix).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            weeklyResetAt: (quotaUsage?.weeklyResetAtUnix ?? weeklyResetAtUnix).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            overageBalanceMicros: quotaUsage?.overageBalanceMicros ?? overageBalanceMicros,
            isStaleFallback: isStaleFallback
        )
    }
}

struct DesktopQuotaAuthStatus: Decodable, Equatable {
    let userStatusProtoBinaryBase64: String?
    let apiKey: String?

    func snapshot(appName: String, isStaleFallback: Bool = false) -> DesktopQuotaSnapshot? {
        guard let userStatusProtoBinaryBase64,
              let data = Data(base64Encoded: userStatusProtoBinaryBase64),
              let userStatus = MinimalProtobufMessage(data: data),
              let planStatus = userStatus.message(field: 13) else {
            return nil
        }

        let planInfo = planStatus.message(field: 1)
        return DesktopQuotaSnapshot(
            appName: appName,
            planName: planInfo?.string(field: 2),
            billingStrategy: (planInfo?.varint(field: 35) == 2) ? "quota" : nil,
            cycleStart: planStatus.timestamp(field: 2),
            cycleEnd: planStatus.timestamp(field: 3),
            dailyRemainingPercent: planStatus.int(field: 14),
            weeklyRemainingPercent: planStatus.int(field: 15),
            dailyResetAt: planStatus.unixDate(field: 17),
            weeklyResetAt: planStatus.unixDate(field: 18),
            overageBalanceMicros: planStatus.signedInt64(field: 16),
            isStaleFallback: isStaleFallback
        )
    }

    var metadata: Data {
        var data = Data()
        data.append(MinimalProtobufWriter.string(1, "windsurf"))
        data.append(MinimalProtobufWriter.string(7, "1.110.1"))
        data.append(MinimalProtobufWriter.string(28, "desktop"))
        data.append(MinimalProtobufWriter.string(12, "Devin"))
        data.append(MinimalProtobufWriter.string(2, "3.4.22"))
        if let apiKey {
            data.append(MinimalProtobufWriter.string(3, apiKey))
        }
        data.append(MinimalProtobufWriter.string(4, Locale.current.identifier))
        data.append(MinimalProtobufWriter.string(5, "darwin"))
        data.append(MinimalProtobufWriter.string(8, "arm64"))
        data.append(MinimalProtobufWriter.string(10, "resetstat"))
        data.append(MinimalProtobufWriter.string(11, "127.0.0.1"))
        data.append(MinimalProtobufWriter.string(13, "LimitLens"))
        data.append(MinimalProtobufWriter.varint(15, 1))

        if let userStatusProtoBinaryBase64,
           let userStatusData = Data(base64Encoded: userStatusProtoBinaryBase64),
           let userStatus = MinimalProtobufMessage(data: userStatusData) {
            if let userId = userStatus.string(field: 36) {
                data.append(MinimalProtobufWriter.string(20, userId))
            }
            if let planStatus = userStatus.message(field: 13),
               let planInfo = planStatus.message(field: 1),
               let planName = planInfo.string(field: 2) {
                data.append(MinimalProtobufWriter.string(26, planName))
            }
            if let teamId = userStatus.string(field: 5) {
                data.append(MinimalProtobufWriter.string(32, teamId))
            }
        }

        data.append(MinimalProtobufWriter.string(27, "resetstat"))
        return data
    }
}

private enum MinimalProtobufWriter {
    static func string(_ field: Int, _ value: String) -> Data {
        let bytes = Data(value.utf8)
        var data = key(field, wireType: 2)
        data.append(varintValue(UInt64(bytes.count)))
        data.append(bytes)
        return data
    }

    static func message(_ field: Int, _ value: Data) -> Data {
        var data = key(field, wireType: 2)
        data.append(varintValue(UInt64(value.count)))
        data.append(value)
        return data
    }

    static func varint(_ field: Int, _ value: UInt64) -> Data {
        var data = key(field, wireType: 0)
        data.append(varintValue(value))
        return data
    }

    private static func key(_ field: Int, wireType: UInt64) -> Data {
        varintValue((UInt64(field) << 3) | wireType)
    }

    private static func varintValue(_ value: UInt64) -> Data {
        var value = value
        var data = Data()
        while true {
            let byte = UInt8(value & 0x7f)
            value >>= 7
            if value == 0 {
                data.append(byte)
                return data
            }
            data.append(byte | 0x80)
        }
    }
}

private struct MinimalProtobufMessage: Equatable {
    private let fields: [Int: [FieldValue]]

    init?(data: Data) {
        var parser = MinimalProtobufParser(data: Array(data))
        guard let fields = try? parser.parseFields(until: Array(data).count) else {
            return nil
        }
        self.fields = Dictionary(grouping: fields, by: \.number)
    }

    private init(fields: [Int: [FieldValue]]) {
        self.fields = fields
    }

    func message(field: Int) -> MinimalProtobufMessage? {
        guard let data = fields[field]?.compactMap(\.bytes).first else {
            return nil
        }
        return MinimalProtobufMessage(data: Data(data))
    }

    func string(field: Int) -> String? {
        fields[field]?.compactMap(\.bytes).compactMap { String(data: Data($0), encoding: .utf8) }.first
    }

    func varint(field: Int) -> UInt64? {
        fields[field]?.compactMap(\.varint).first
    }

    func int(field: Int) -> Int? {
        varint(field: field).flatMap { Int(exactly: $0) }
    }

    func signedInt64(field: Int) -> Int64? {
        guard let value = varint(field: field) else {
            return nil
        }
        return Int64(bitPattern: value)
    }

    func unixDate(field: Int) -> Date? {
        signedInt64(field: field).flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
    }

    func timestamp(field: Int) -> Date? {
        guard let message = message(field: field), let seconds = message.signedInt64(field: 1) else {
            return nil
        }
        let nanos = message.signedInt64(field: 2) ?? 0
        return Date(timeIntervalSince1970: TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000)
    }
}

private struct FieldValue: Equatable {
    let number: Int
    let varint: UInt64?
    let bytes: [UInt8]?
}

private struct MinimalProtobufParser {
    var data: [UInt8]
    var index = 0

    mutating func parseFields(until end: Int) throws -> [FieldValue] {
        var values: [FieldValue] = []
        while index < end {
            let key = try readVarint()
            let number = Int(key >> 3)
            let wireType = key & 0x7

            switch wireType {
            case 0:
                values.append(FieldValue(number: number, varint: try readVarint(), bytes: nil))
            case 1:
                try skip(8)
            case 2:
                let length = Int(try readVarint())
                guard index + length <= data.count else { throw ProtobufError.truncated }
                values.append(FieldValue(number: number, varint: nil, bytes: Array(data[index..<index + length])))
                index += length
            case 5:
                try skip(4)
            default:
                throw ProtobufError.unsupportedWireType
            }
        }
        return values
    }

    private mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < data.count {
            let byte = data[index]
            index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift > 63 { throw ProtobufError.invalidVarint }
        }
        throw ProtobufError.truncated
    }

    private mutating func skip(_ count: Int) throws {
        guard index + count <= data.count else { throw ProtobufError.truncated }
        index += count
    }

    private enum ProtobufError: Error {
        case invalidVarint
        case truncated
        case unsupportedWireType
    }
}
