import Foundation

public enum SwiftlyFeedbackError: Error, LocalizedError, Equatable {
    case invalidResponse
    case badRequest(message: String?)
    case unauthorized
    case invalidApiKey
    case notFound
    case conflict
    case serverError(statusCode: Int)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case feedbackLimitReached(message: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: .errorInvalidResponseMessage)
        case .badRequest(let message):
            return message ?? String(localized: .errorBadRequestMessage)
        case .unauthorized:
            return String(localized: .errorUnauthorizedMessage)
        case .invalidApiKey:
            return String(localized: .errorInvalidApiKeyMessage)
        case .notFound:
            return String(localized: .errorNotFoundMessage)
        case .conflict:
            return String(localized: .errorConflictMessage)
        case .serverError(let statusCode):
            return String(localized: .errorServerErrorMessage(statusCode))
        case .networkError(let error):
            return String(localized: .errorNetworkErrorMessage(error.localizedDescription))
        case .decodingError(let error):
            return String(localized: .errorDecodingErrorMessage(error.localizedDescription))
        case .feedbackLimitReached(let message):
            return message ?? String(localized: .errorFeedbackLimitMessage)
        }
    }

    public static func == (lhs: SwiftlyFeedbackError, rhs: SwiftlyFeedbackError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.invalidApiKey, .invalidApiKey),
             (.notFound, .notFound),
             (.conflict, .conflict):
            return true
        case let (.badRequest(lhsMsg), .badRequest(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode
        case let (.networkError(lhsErr), .networkError(rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        case let (.decodingError(lhsErr), .decodingError(rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        case let (.feedbackLimitReached(lhsMsg), .feedbackLimitReached(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
