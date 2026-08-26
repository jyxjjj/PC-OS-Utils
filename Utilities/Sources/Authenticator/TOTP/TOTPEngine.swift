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
        let truncated =
            UInt32(hmacBytes[offset] & 0x7F) << 24
            | UInt32(hmacBytes[offset + 1]) << 16
            | UInt32(hmacBytes[offset + 2]) << 8
            | UInt32(hmacBytes[offset + 3])

        let modulo = UInt32(pow(10.0, Double(digits)))
        let code = truncated % modulo
        return String(
            format: AppConstants.Authenticator.OTPAuth.codeFormat,
            digits,
            code
        )
    }

    // MARK: - OTP Auth URI parser

    static func parseOTPAuthURI(_ uri: String) throws -> OTPAuthParameters {
        let input = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: input),
            components.scheme?.lowercased() == AppConstants.Authenticator.OTPAuth.scheme,
            components.host?.lowercased() == AppConstants.Authenticator.OTPAuth.host,
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.fragment == nil
        else {
            throw TOTPError.invalidURI
        }

        let label =
            components.path.hasPrefix(AppConstants.Authenticator.OTPAuth.pathPrefix)
            ? String(components.path.dropFirst())
            : components.path
        var issuer = ""
        var account = label
        if label.contains(AppConstants.Authenticator.labelSeparator) {
            let parts = label.split(
                separator: AppConstants.Authenticator.labelSeparator,
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

        guard
            let encodedSecret = try queryValue(
                AppConstants.Authenticator.OTPAuth.secretQueryName
            ),
            !encodedSecret.isEmpty
        else {
            throw TOTPError.missingSecret
        }
        let secret = try Base32Codec.decode(encodedSecret)

        if let queryIssuer = try queryValue(AppConstants.Authenticator.OTPAuth.issuerQueryName) {
            issuer = queryIssuer
        }
        issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(issuer.isEmpty && account.isEmpty) else {
            throw TOTPError.missingAccount
        }
        guard !issuer.contains(AppConstants.Authenticator.labelSeparator),
            !account.contains(AppConstants.Authenticator.labelSeparator)
        else {
            throw TOTPError.invalidLabel
        }

        var algorithm = TOTPAlgorithm.sha256
        if let rawAlgorithm = try queryValue(
            AppConstants.Authenticator.OTPAuth.algorithmQueryName
        ) {
            guard rawAlgorithm.allSatisfy({ $0.asciiValue != nil }),
                let parsed = TOTPAlgorithm(rawValue: rawAlgorithm.uppercased())
            else {
                throw TOTPError.invalidAlgorithm
            }
            algorithm = parsed
        }

        var digits = AppConstants.Authenticator.defaultDigits
        if let rawDigits = try queryValue(AppConstants.Authenticator.OTPAuth.digitsQueryName) {
            guard isASCIIDecimal(rawDigits),
                let parsed = Int(rawDigits),
                (AppConstants.Authenticator.minimumDigits ... AppConstants.Authenticator.maximumDigits).contains(parsed)
            else {
                throw TOTPError.invalidDigits
            }
            digits = parsed
        }

        var period = AppConstants.Authenticator.defaultPeriod
        if let rawPeriod = try queryValue(AppConstants.Authenticator.OTPAuth.periodQueryName) {
            guard isASCIIDecimal(rawPeriod),
                let parsed = Int(rawPeriod),
                AppConstants.Authenticator.supportedPeriods.contains(parsed)
            else {
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
        !value.isEmpty
            && value.allSatisfy {
                $0.isASCII && $0.isNumber
            }
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
                    AppConstants.Authenticator.OTPAuth.invalidURI
                case .missingSecret:
                    AppConstants.Authenticator.OTPAuth.missingSecret
                case .missingAccount:
                    AppConstants.Authenticator.OTPAuth.missingAccount
                case .invalidLabel:
                    AppConstants.Authenticator.OTPAuth.invalidLabel
                case .invalidAlgorithm:
                    AppConstants.Authenticator.OTPAuth.invalidAlgorithm
                case .invalidDigits:
                    AppConstants.Authenticator.OTPAuth.invalidDigits
                case .invalidPeriod:
                    AppConstants.Authenticator.OTPAuth.invalidPeriod
                case .duplicateParameter(let name):
                    String(
                        format: AppConstants.Authenticator.OTPAuth.duplicateParameterFormat,
                        name
                    )
                case .invalidParameter(let name):
                    String(
                        format: AppConstants.Authenticator.OTPAuth.missingParameterValueFormat,
                        name
                    )
            }
        }
    }
}
