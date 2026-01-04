import Foundation

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

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct SignupRequest: Encodable {
    let email: String
    let name: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

struct DeleteAccountRequest: Encodable {
    let password: String
}

struct VerifyEmailRequest: Encodable {
    let code: String
}

struct VerifyEmailResponse: Decodable {
    let message: String
    let user: User
}

struct MessageResponse: Decodable {
    let message: String
}

struct UpdateNotificationSettingsRequest: Encodable {
    let notifyNewFeedback: Bool?
    let notifyNewComments: Bool?
}
