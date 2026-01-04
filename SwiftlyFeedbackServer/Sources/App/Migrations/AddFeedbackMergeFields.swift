import Fluent

struct AddFeedbackMergeFields: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("feedbacks")
            .field("merged_into_id", .uuid, .references("feedbacks", "id", onDelete: .setNull))
            .field("merged_at", .datetime)
            .field("merged_feedback_ids", .array(of: .uuid))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("feedbacks")
            .deleteField("merged_into_id")
            .deleteField("merged_at")
            .deleteField("merged_feedback_ids")
            .update()
    }
}
