import Fluent

struct AddUserNotificationSettings: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("notify_new_feedback", .bool, .required, .sql(.default(true)))
            .field("notify_new_comments", .bool, .required, .sql(.default(true)))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("notify_new_feedback")
            .deleteField("notify_new_comments")
            .update()
    }
}
