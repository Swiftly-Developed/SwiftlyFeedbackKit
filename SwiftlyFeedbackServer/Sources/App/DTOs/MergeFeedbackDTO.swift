import Vapor

struct MergeFeedbackRequest: Content {
    let primaryFeedbackId: UUID
    let secondaryFeedbackIds: [UUID]
}

struct MergeFeedbackResponse: Content {
    let primaryFeedback: FeedbackResponseDTO
    let mergedCount: Int
    let totalVotes: Int
    let totalComments: Int
}
