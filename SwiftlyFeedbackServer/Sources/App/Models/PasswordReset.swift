import Fluent
import Vapor

final class PasswordReset: Model, Content, @unchecked Sendable {
    static let schema = "password_resets"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "token")
    var token: String

    @Field(key: "expires_at")
    var expiresAt: Date

    @OptionalField(key: "used_at")
    var usedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        expiresInHours: Int = 1
    ) {
        self.id = id
        self.$user.id = userId
        self.token = Self.generateResetCode()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresInHours * 60 * 60))
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isUsed: Bool {
        usedAt != nil
    }

    /// Generates a user-friendly 8-character reset code (uppercase letters and numbers, no ambiguous chars)
    static func generateResetCode() -> String {
        // Exclude ambiguous characters: 0, O, I, 1, L
        let chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}
