import Foundation

nonisolated enum Base32Codec {
    private static let alphabet = Array(AppConstants.Authenticator.Base32.alphabet)
    private static let values = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) }
    )

    static func decode(_ input: String) throws -> Data {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.unicodeScalars.allSatisfy(\.isASCII) else {
            throw Base32Error.nonASCII
        }
        let cleaned = trimmed.uppercased()
        guard !cleaned.isEmpty else { throw Base32Error.empty }

        let payload: Substring
        let paddingCount: Int
        if let paddingStart = cleaned.firstIndex(of: AppConstants.Authenticator.Base32.padding) {
            payload = cleaned[..<paddingStart]
            let padding = cleaned[paddingStart...]
            guard padding.allSatisfy({
                $0 == AppConstants.Authenticator.Base32.padding
            }) else {
                throw Base32Error.invalidPadding
            }
            paddingCount = padding.count
        } else {
            payload = cleaned[...]
            paddingCount = 0
        }

        guard !payload.isEmpty else { throw Base32Error.empty }
        let remainder = payload.count % 8
        let requiredPadding = switch remainder {
        case 0: 0
        case 2: 6
        case 4: 4
        case 5: 3
        case 7: 1
        default: throw Base32Error.invalidLength
        }
        if paddingCount > 0 {
            guard cleaned.count.isMultiple(of: 8), paddingCount == requiredPadding else {
                throw Base32Error.invalidPadding
            }
        }

        var buffer = 0
        var bitCount = 0
        var output = Data()
        output.reserveCapacity(payload.count * 5 / 8)

        for character in payload {
            guard let value = values[character] else {
                throw Base32Error.invalidCharacter(character)
            }
            buffer = (buffer << 5) | value
            bitCount += 5
            while bitCount >= 8 {
                bitCount -= 8
                output.append(UInt8((buffer >> bitCount) & 0xFF))
                buffer = bitCount == 0 ? 0 : buffer & ((1 << bitCount) - 1)
            }
        }

        guard buffer == 0 else { throw Base32Error.nonZeroPaddingBits }
        return output
    }

    static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }

        var result = ""
        result.reserveCapacity((data.count * 8 + 4) / 5)
        var buffer = 0
        var bitCount = 0

        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append(alphabet[(buffer >> bitCount) & 0x1F])
                buffer = bitCount == 0 ? 0 : buffer & ((1 << bitCount) - 1)
            }
        }
        if bitCount > 0 {
            result.append(alphabet[(buffer << (5 - bitCount)) & 0x1F])
        }
        return result
    }

    enum Base32Error: Error, LocalizedError, Sendable {
        case empty
        case invalidCharacter(Character)
        case nonASCII
        case invalidLength
        case invalidPadding
        case nonZeroPaddingBits

        var errorDescription: String? {
            switch self {
            case .empty:
                AppConstants.Authenticator.Base32.emptySecret
            case let .invalidCharacter(character):
                String(
                    format: AppConstants.Authenticator.Base32.invalidCharacterFormat,
                    String(character)
                )
            case .nonASCII:
                AppConstants.Authenticator.Base32.nonASCII
            case .invalidLength:
                AppConstants.Authenticator.Base32.invalidLength
            case .invalidPadding:
                AppConstants.Authenticator.Base32.invalidPadding
            case .nonZeroPaddingBits:
                AppConstants.Authenticator.Base32.nonZeroPaddingBits
            }
        }
    }
}
