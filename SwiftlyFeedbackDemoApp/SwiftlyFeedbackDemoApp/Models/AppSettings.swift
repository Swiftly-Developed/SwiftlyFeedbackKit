import SwiftUI
import SwiftlyFeedbackKit

@MainActor
@Observable
final class AppSettings {
    // MARK: - User Settings

    var userEmail: String {
        didSet { UserDefaults.standard.set(userEmail, forKey: "userEmail") }
    }

    var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    var customUserId: String {
        didSet {
            UserDefaults.standard.set(customUserId, forKey: "customUserId")
            if !customUserId.isEmpty {
                SwiftlyFeedback.updateUser(customID: customUserId)
            }
        }
    }

    // MARK: - Subscription Settings

    var subscriptionType: SubscriptionType {
        didSet {
            UserDefaults.standard.set(subscriptionType.rawValue, forKey: "subscriptionType")
            updateSubscription()
        }
    }

    var subscriptionAmount: Double {
        didSet {
            UserDefaults.standard.set(subscriptionAmount, forKey: "subscriptionAmount")
            updateSubscription()
        }
    }

    // MARK: - SDK Configuration

    var allowUndoVote: Bool {
        didSet {
            UserDefaults.standard.set(allowUndoVote, forKey: "allowUndoVote")
            SwiftlyFeedback.config.allowUndoVote = allowUndoVote
        }
    }

    var showCommentSection: Bool {
        didSet {
            UserDefaults.standard.set(showCommentSection, forKey: "showCommentSection")
            SwiftlyFeedback.config.showCommentSection = showCommentSection
        }
    }

    var showEmailField: Bool {
        didSet {
            UserDefaults.standard.set(showEmailField, forKey: "showEmailField")
            SwiftlyFeedback.config.showEmailField = showEmailField
        }
    }

    var showStatusBadge: Bool {
        didSet {
            UserDefaults.standard.set(showStatusBadge, forKey: "showStatusBadge")
            SwiftlyFeedback.config.showStatusBadge = showStatusBadge
        }
    }

    var showCategoryBadge: Bool {
        didSet {
            UserDefaults.standard.set(showCategoryBadge, forKey: "showCategoryBadge")
            SwiftlyFeedback.config.showCategoryBadge = showCategoryBadge
        }
    }

    var showVoteCount: Bool {
        didSet {
            UserDefaults.standard.set(showVoteCount, forKey: "showVoteCount")
            SwiftlyFeedback.config.showVoteCount = showVoteCount
        }
    }

    var expandDescriptionInList: Bool {
        didSet {
            UserDefaults.standard.set(expandDescriptionInList, forKey: "expandDescriptionInList")
            SwiftlyFeedback.config.expandDescriptionInList = expandDescriptionInList
        }
    }

    // MARK: - Initialization

    init() {
        let defaults = UserDefaults.standard

        // Load saved values
        self.userEmail = defaults.string(forKey: "userEmail") ?? ""
        self.userName = defaults.string(forKey: "userName") ?? ""
        self.customUserId = defaults.string(forKey: "customUserId") ?? ""

        let savedSubType = defaults.string(forKey: "subscriptionType") ?? SubscriptionType.none.rawValue
        self.subscriptionType = SubscriptionType(rawValue: savedSubType) ?? .none
        self.subscriptionAmount = defaults.double(forKey: "subscriptionAmount")

        self.allowUndoVote = defaults.object(forKey: "allowUndoVote") as? Bool ?? true
        self.showCommentSection = defaults.object(forKey: "showCommentSection") as? Bool ?? true
        self.showEmailField = defaults.object(forKey: "showEmailField") as? Bool ?? true
        self.showStatusBadge = defaults.object(forKey: "showStatusBadge") as? Bool ?? true
        self.showCategoryBadge = defaults.object(forKey: "showCategoryBadge") as? Bool ?? true
        self.showVoteCount = defaults.object(forKey: "showVoteCount") as? Bool ?? true
        self.expandDescriptionInList = defaults.object(forKey: "expandDescriptionInList") as? Bool ?? false

        // Apply SDK configuration after loading
        applySDKConfiguration()
    }

    // MARK: - Methods

    private func applySDKConfiguration() {
        SwiftlyFeedback.config.allowUndoVote = allowUndoVote
        SwiftlyFeedback.config.showCommentSection = showCommentSection
        SwiftlyFeedback.config.showEmailField = showEmailField
        SwiftlyFeedback.config.showStatusBadge = showStatusBadge
        SwiftlyFeedback.config.showCategoryBadge = showCategoryBadge
        SwiftlyFeedback.config.showVoteCount = showVoteCount
        SwiftlyFeedback.config.expandDescriptionInList = expandDescriptionInList

        if !customUserId.isEmpty {
            SwiftlyFeedback.updateUser(customID: customUserId)
        }

        updateSubscription()
    }

    private func updateSubscription() {
        guard subscriptionAmount > 0 else {
            SwiftlyFeedback.clearUserPayment()
            return
        }

        switch subscriptionType {
        case .none:
            SwiftlyFeedback.clearUserPayment()
        case .weekly:
            SwiftlyFeedback.updateUser(payment: .weekly(subscriptionAmount))
        case .monthly:
            SwiftlyFeedback.updateUser(payment: .monthly(subscriptionAmount))
        case .quarterly:
            SwiftlyFeedback.updateUser(payment: .quarterly(subscriptionAmount))
        case .yearly:
            SwiftlyFeedback.updateUser(payment: .yearly(subscriptionAmount))
        }
    }
}

// MARK: - Subscription Type

enum SubscriptionType: String, CaseIterable, Identifiable {
    case none = "none"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }
}
