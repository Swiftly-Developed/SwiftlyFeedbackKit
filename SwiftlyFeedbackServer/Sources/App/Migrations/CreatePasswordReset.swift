import Fluent

struct CreatePasswordReset: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("password_resets")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("token", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("used_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "token")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("password_resets").delete()
    }
}
