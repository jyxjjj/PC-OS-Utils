import Foundation

nonisolated enum TOTPAlgorithm: String, CaseIterable, Codable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

nonisolated struct TOTPEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var serviceName: String
    var username: String
    let secret: Data
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: Int
}
