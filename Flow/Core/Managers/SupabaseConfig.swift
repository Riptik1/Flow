import Foundation

enum SupabaseConfig {
    static let projectURL = URL(string: "https://zaecghzqdojvlguamtlk.supabase.co")!
    static let publishableKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphZWNnaHpxZG9qdmxndWFtdGxrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4NTg5MjYsImV4cCI6MjA5OTQzNDkyNn0.EuhBHLMTUgqFmbS0_GEmocCow-hVQEKOjb6leWIduFk"
}

struct PairingCodeResponse: Decodable {
    let code: String
    let expiresAt: Date

    private enum CodingKeys: String, CodingKey {
        case code
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        let rawExpiresAt = try container.decode(String.self, forKey: .expiresAt)
        guard let parsed = PairingCodeResponse.parseISO8601(rawExpiresAt) else {
            throw DecodingError.dataCorruptedError(forKey: .expiresAt, in: container, debugDescription: "Unrecognized date format: \(rawExpiresAt)")
        }
        expiresAt = parsed
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractionalSeconds.date(from: value) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

struct MacDeviceSummary: Decodable {
    let id: UUID
    let deviceName: String
    let deviceModel: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case deviceModel = "device_model"
    }
}

struct IPhoneDeviceSummary: Decodable {
    let id: UUID
    let deviceName: String
    let deviceModel: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case deviceModel = "device_model"
    }
}

struct RedeemPairingCodeResponse: Decodable {
    let deviceLinkID: UUID
    let mac: MacDeviceSummary

    enum CodingKeys: String, CodingKey {
        case deviceLinkID = "device_link_id"
        case mac
    }
}

struct DeviceLinkRow: Decodable {
    let id: UUID
    let macID: UUID
    let iphoneID: UUID
    let createdAt: Date
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case macID = "mac_id"
        case iphoneID = "iphone_id"
        case createdAt = "created_at"
        case revokedAt = "revoked_at"
    }
}
