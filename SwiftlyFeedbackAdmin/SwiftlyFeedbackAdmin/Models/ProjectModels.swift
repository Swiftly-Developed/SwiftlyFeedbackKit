import Foundation

struct Project: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let apiKey: String
    let description: String?
    let ownerId: UUID
    let ownerEmail: String?
    let isArchived: Bool
    let archivedAt: Date?
    let feedbackCount: Int
    let memberCount: Int
    let createdAt: Date?
    let updatedAt: Date?
}

struct ProjectListItem: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let isArchived: Bool
    let isOwner: Bool
    let role: ProjectRole?
    let feedbackCount: Int
    let createdAt: Date?
}

extension ProjectListItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ProjectListItem, rhs: ProjectListItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ProjectMember: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    let userEmail: String
    let userName: String
    let role: ProjectRole
    let createdAt: Date?
}

enum ProjectRole: String, Codable, CaseIterable, Sendable, Hashable {
    case admin
    case member
    case viewer

    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }

    var roleDescription: String {
        switch self {
        case .admin: return "Can manage project settings and members"
        case .member: return "Can view and respond to feedback"
        case .viewer: return "Can only view feedback"
        }
    }
}

struct CreateProjectRequest: Encodable {
    let name: String
    let description: String?
}

struct UpdateProjectRequest: Encodable {
    let name: String?
    let description: String?
}

struct AddMemberRequest: Encodable {
    let email: String
    let role: ProjectRole
}

struct UpdateMemberRoleRequest: Encodable {
    let role: ProjectRole
}

struct ProjectInvite: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let email: String
    let role: ProjectRole
    let code: String?
    let expiresAt: Date
    let createdAt: Date?
}

struct AddMemberResponse: Codable, Sendable {
    let member: ProjectMember?
    let invite: ProjectInvite?
    let inviteSent: Bool
}

struct AcceptInviteRequest: Encodable {
    let code: String
}

struct InvitePreview: Codable, Sendable {
    let projectName: String
    let projectDescription: String?
    let invitedByName: String
    let role: ProjectRole
    let expiresAt: Date
    let emailMatches: Bool
    let inviteEmail: String
}

struct AcceptInviteResponse: Codable, Sendable {
    let projectId: UUID
    let projectName: String
    let role: ProjectRole
}
