import Foundation

// MARK: - Auth Models
//
// All models are marked `nonisolated` to opt out of the project's default MainActor isolation.
// This allows their Codable conformances to be used from any actor context (e.g., AdminAPIClient).

nonisolated
struct User: Codable, Identifiable, Sendable {
    let id: UUID
    let email: String
    let name: String
    let isAdmin: Bool
    let isEmailVerified: Bool
    let notifyNewFeedback: Bool
    let notifyNewComments: Bool
    let createdAt: Date?
}

nonisolated
struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

nonisolated
struct SignupRequest: Encodable, Sendable {
    let email: String
    let name: String
    let password: String
}

nonisolated
struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: User
}

nonisolated
struct ChangePasswordRequest: Encodable, Sendable {
    let currentPassword: String
    let newPassword: String
}

nonisolated
struct DeleteAccountRequest: Encodable, Sendable {
    let password: String
}

nonisolated
struct VerifyEmailRequest: Encodable, Sendable {
    let code: String
}

nonisolated
struct VerifyEmailResponse: Decodable, Sendable {
    let message: String
    let user: User
}

nonisolated
struct MessageResponse: Decodable, Sendable {
    let message: String
}

nonisolated
struct UpdateNotificationSettingsRequest: Encodable, Sendable {
    let notifyNewFeedback: Bool?
    let notifyNewComments: Bool?
}

nonisolated
struct ForgotPasswordRequest: Encodable, Sendable {
    let email: String
}

nonisolated
struct ResetPasswordRequest: Encodable, Sendable {
    let code: String
    let newPassword: String
}

nonisolated
struct OverrideSubscriptionTierRequest: Encodable, Sendable {
    let tier: String
}

nonisolated
struct SubscriptionInfoDTO: Decodable, Sendable {
    let tier: SubscriptionTier
    let status: String?
    let productId: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case tier, status
        case productId = "product_id"
        case expiresAt = "expires_at"
    }
}
