import Foundation

/// Predefined view events that are automatically tracked by the SDK.
public enum PredefinedView: String, Sendable {
    /// Feedback list view
    case feedbackList = "feedback_list"
    /// Feedback detail view
    case feedbackDetail = "feedback_detail"
    /// Submit feedback view
    case submitFeedback = "submit_feedback"
}

/// Response from tracking a view event.
public struct ViewEventResponse: Codable, Sendable {
    public let id: UUID
    public let eventName: String
    public let userId: String
    public let properties: [String: String]?
    public let createdAt: Date?
}
