import CryptoKit
import Foundation

nonisolated struct OTPAuthParameters: Sendable {
    let secret: Data
    let issuer: String
    let account: String
    let algorithm: TOTPAlgorithm
    let digits: Int
    let period: Int

    var serviceName: String { issuer.isEmpty ? account : issuer }
    var username: String { issuer.isEmpty ? "" : account }
    var base32Secret: String { Base32Codec.encode(secret) }
}

nonisolated struct TOTPEngine {
    static let supportedPeriods = [15, 30, 45, 60]

    static func generateCode(
        secret: Data,
        algorithm: TOTPAlgorithm,
        digits: Int,
        period: Int,
        date: Date = Date()
    ) -> String {
        let counter = UInt64(date.timeIntervalSince1970) / UInt64(period)
        return hotp(secret: secret, counter: counter, algorithm: algorithm, digits: digits)
    }

    static func timing(
        period: Int,
        date: Date = Date()
    ) -> (remaining: Double, fraction: Double) {
        let duration = Double(period)
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: duration)
        return (duration - elapsed, elapsed / duration)
    }

    // MARK: - HOTP (RFC 4226)

    private static func hotp(
        secret: Data,
        counter: UInt64,
        algorithm: TOTPAlgorithm,
        digits: Int
    ) -> String {
        var counterBE = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBE) { Data($0) }

        let key = SymmetricKey(data: secret)
        let hmacBytes: Data
        switch algorithm {
        case .sha1:
            hmacBytes = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
        case .sha256:
            hmacBytes = Data(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            hmacBytes = Data(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        // Dynamic truncation (RFC 4226 §5.4)
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated = UInt32(hmacBytes[offset] & 0x7F) << 24
            | UInt32(hmacBytes[offset + 1]) << 16
            | UInt32(hmacBytes[offset + 2]) << 8
            | UInt32(hmacBytes[offset + 3])

        let modulo = UInt32(pow(10.0, Double(digits)))
        let code = truncated % modulo
        return String(format: "%0\(digits)d", code)
    }

    // MARK: - OTP Auth URI parser

    static func parseOTPAuthURI(_ uri: String) throws -> OTPAuthParameters {
        let input = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: input),
              components.scheme?.lowercased() == "otpauth",
              components.host?.lowercased() == "totp",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil else {
            throw TOTPError.invalidURI
        }

        let label = components.path.hasPrefix("/")
            ? String(components.path.dropFirst())
            : components.path
        var issuer = ""
        var account = label
        if label.contains(":") {
            let parts = label.split(
                separator: ":",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            issuer = String(parts[0])
            account = String(parts[1])
        }

        let queryItems = Dictionary(
            grouping: components.queryItems ?? [],
            by: \URLQueryItem.name
        )
        func queryValue(_ name: String) throws -> String? {
            guard let items = queryItems[name] else { return nil }
            guard items.count == 1 else {
                throw TOTPError.duplicateParameter(name)
            }
            guard let value = items[0].value else {
                throw TOTPError.invalidParameter(name)
            }
            return value
        }

        guard let encodedSecret = try queryValue("secret"),
              !encodedSecret.isEmpty else {
            throw TOTPError.missingSecret
        }
        let secret = try Base32Codec.decode(encodedSecret)

        if let queryIssuer = try queryValue("issuer") {
            issuer = queryIssuer
        }
        issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(issuer.isEmpty && account.isEmpty) else {
            throw TOTPError.missingAccount
        }
        guard !issuer.contains(":"), !account.contains(":") else {
            throw TOTPError.invalidLabel
        }

        var algorithm = TOTPAlgorithm.sha1
        if let rawAlgorithm = try queryValue("algorithm") {
            guard rawAlgorithm.allSatisfy({ $0.asciiValue != nil }),
                  let parsed = TOTPAlgorithm(rawValue: rawAlgorithm.uppercased()) else {
                throw TOTPError.invalidAlgorithm
            }
            algorithm = parsed
        }

        var digits = 6
        if let rawDigits = try queryValue("digits") {
            guard isASCIIDecimal(rawDigits),
                  let parsed = Int(rawDigits),
                  (6 ... 8).contains(parsed) else {
                throw TOTPError.invalidDigits
            }
            digits = parsed
        }

        var period = 30
        if let rawPeriod = try queryValue("period") {
            guard isASCIIDecimal(rawPeriod),
                  let parsed = Int(rawPeriod),
                  supportedPeriods.contains(parsed) else {
                throw TOTPError.invalidPeriod
            }
            period = parsed
        }

        return OTPAuthParameters(
            secret: secret,
            issuer: issuer,
            account: account,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }

    private static func isASCIIDecimal(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48 ... 57).contains($0) }
    }

    // MARK: - Errors

    enum TOTPError: Error, LocalizedError, Sendable {
        case invalidURI
        case missingSecret
        case missingAccount
        case invalidLabel
        case invalidAlgorithm
        case invalidDigits
        case invalidPeriod
        case duplicateParameter(String)
        case invalidParameter(String)

        var errorDescription: String? {
            switch self {
            case .invalidURI:
                "OTP Auth URI 无效"
            case .missingSecret:
                "URI 中缺少密钥"
            case .missingAccount:
                "URI 中缺少账户名称"
            case .invalidLabel:
                "服务名称和用户名不能包含冒号"
            case .invalidAlgorithm:
                "OTP Auth URI 的算法无效"
            case .invalidDigits:
                "OTP Auth URI 的位数必须为 6 到 8"
            case .invalidPeriod:
                "OTP Auth URI 的周期必须为 15、30、45 或 60 秒"
            case let .duplicateParameter(name):
                "OTP Auth URI 包含重复参数: \"\(name)\""
            case let .invalidParameter(name):
                "OTP Auth URI 参数缺少值: \"\(name)\""
            }
        }
    }
}
