# CLAUDE.md - SwiftlyFeedbackServer

Vapor 4 backend API server with PostgreSQL database.

## Build & Run

```bash
# Build
swift build

# Run (starts on http://localhost:8080)
swift run

# Test
swift test
```

## Database Setup

```bash
# Create database (native)
createdb swiftly_feedback

# Or with Docker
docker run --name swiftly-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=swiftly_feedback -p 5432:5432 -d postgres
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_HOST` | localhost | PostgreSQL host |
| `DATABASE_PORT` | 5432 | PostgreSQL port |
| `DATABASE_USERNAME` | postgres | Database username |
| `DATABASE_PASSWORD` | postgres | Database password |
| `DATABASE_NAME` | swiftly_feedback | Database name |

## Directory Structure

```
Sources/App/
├── Controllers/          # API route handlers
│   ├── AuthController.swift
│   ├── ProjectController.swift
│   ├── FeedbackController.swift
│   ├── VoteController.swift
│   ├── CommentController.swift
│   ├── SDKUserController.swift
│   ├── ViewEventController.swift
│   └── DashboardController.swift
├── Models/               # Fluent database models
│   ├── User.swift
│   ├── UserToken.swift
│   ├── Project.swift
│   ├── ProjectMember.swift
│   ├── ProjectInvite.swift
│   ├── EmailVerification.swift
│   ├── Feedback.swift
│   ├── Vote.swift
│   ├── Comment.swift
│   ├── SDKUser.swift
│   └── ViewEvent.swift
├── Migrations/           # Database migrations
├── DTOs/                 # Data transfer objects
├── Services/             # Business logic services
│   ├── EmailService.swift    # Email notifications via Resend
│   ├── SlackService.swift    # Slack webhook notifications
│   └── GitHubService.swift   # GitHub Issues integration
├── configure.swift       # App configuration
├── routes.swift          # Route registration
└── entrypoint.swift      # Main entry point
```

## Dependencies

- **Vapor 4** - Web framework
- **Fluent** - ORM
- **FluentPostgresDriver** - PostgreSQL driver
- **JWT** - JSON Web Tokens

## API Endpoints

All routes prefixed with `/api/v1`.

### Authentication
- `POST /auth/signup` - Create account (sends verification email)
- `POST /auth/login` - Login (returns token)
- `GET /auth/me` - Get current user (requires auth)
- `POST /auth/logout` - Logout (requires auth)
- `POST /auth/verify-email` - Verify email with 8-character code
- `POST /auth/resend-verification` - Resend verification email (requires auth)
- `PUT /auth/password` - Change password (requires auth)
- `DELETE /auth/account` - Delete account (requires auth)

### Projects (Bearer token required)
- `GET /projects` - List user's projects
- `POST /projects` - Create project (returns API key, assigns random colorIndex 0-7)
- `GET /projects/:id` - Get project details
- `PATCH /projects/:id` - Update project (owner/admin) - supports name, description, colorIndex
- `DELETE /projects/:id` - Delete project (owner only)
- `POST /projects/:id/archive` - Archive project (owner only)
- `POST /projects/:id/unarchive` - Unarchive project (owner only)
- `POST /projects/:id/regenerate-key` - Regenerate API key (owner only)
- `PATCH /projects/:id/slack` - Update Slack settings (owner/admin only)
- `PATCH /projects/:id/statuses` - Update allowed statuses (owner/admin only)
- `PATCH /projects/:id/github` - Update GitHub settings (owner/admin only)
- `POST /projects/:id/github/issue` - Create GitHub issue from feedback (owner/admin only)
- `POST /projects/:id/github/issues` - Bulk create GitHub issues (owner/admin only)

### Project Members (Bearer token required)
- `GET /projects/:id/members` - List members
- `POST /projects/:id/members` - Add member by email (owner/admin)
- `PATCH /projects/:id/members/:memberId` - Update role (owner/admin)
- `DELETE /projects/:id/members/:memberId` - Remove member (owner/admin)

### Feedback (X-API-Key header required)
- `GET /feedbacks` - List feedback (`?status=`, `?category=` filters)
- `POST /feedbacks` - Submit feedback (blocked if archived)
- `GET /feedbacks/:id` - Get feedback details
- `PATCH /feedbacks/:id` - Update feedback (auth + project access)
- `DELETE /feedbacks/:id` - Delete feedback (auth + owner/admin)
- `POST /feedbacks/merge` - Merge feedback items (auth + owner/admin)

### Votes (X-API-Key header required)
- `POST /feedbacks/:id/votes` - Vote (blocked if archived or status is completed/rejected)
- `DELETE /feedbacks/:id/votes` - Remove vote (blocked if archived)

### Comments (X-API-Key header required)
- `GET /feedbacks/:id/comments` - List comments
- `POST /feedbacks/:id/comments` - Add comment (blocked if archived)
- `DELETE /feedbacks/:id/comments/:commentId` - Delete comment (blocked if archived)

### SDK Users (Bearer token required)
- `GET /users/project/:projectId` - List SDK users for a project
- `GET /users/project/:projectId/stats` - Get SDK user stats (total users, MRR totals, averages)
- `GET /users/all` - List SDK users across all projects the user has access to
- `GET /users/all/stats` - Get aggregated SDK user stats across all projects

### View Events
- `POST /events/track` - Track view event (X-API-Key required)
- `GET /events/project/:projectId` - List recent events (Bearer token required)
- `GET /events/project/:projectId/stats?days=N` - Get event statistics with daily breakdown (Bearer token required)
- `GET /events/all/stats?days=N` - Get aggregated event statistics across all projects (Bearer token required)

**Query Parameters:**
- `days` (optional): Number of days to include in statistics (default: 30, max: 365)

### Dashboard (Bearer token required)
- `GET /dashboard/home` - Aggregated KPIs across all user's projects (projects, feedback by status/category, users, comments, votes)

## Code Patterns

### Adding a New Model

1. Create model in `Models/` extending `Model` and `Content`
2. Create migration in `Migrations/`
3. Register migration in `configure.swift`
4. Create DTO in `DTOs/` if needed

### Adding a New Controller

1. Create controller in `Controllers/`
2. Implement route collection conformance
3. Register routes in `routes.swift`

### Authentication

- User authentication uses Bearer tokens via `UserToken` model
- API key authentication uses `X-API-Key` header for SDK requests
- Use `req.auth.require(User.self)` for authenticated routes

## Feedback Merging

The merge endpoint consolidates duplicate feedback items:

### Endpoint
`POST /feedbacks/merge` (Bearer token + owner/admin required)

Request body:
```json
{
  "primary_feedback_id": "uuid",
  "secondary_feedback_ids": ["uuid", "uuid"]
}
```

### What Happens During Merge
1. **Votes** are moved to primary feedback (de-duplicated by userId)
2. **Comments** are migrated with prefix: "[Originally on: {title}] {content}"
3. **Vote count** is recalculated from unique voters
4. **MRR** is recalculated from all unique voters
5. **Secondary feedbacks** are marked as merged (soft delete)

### Database Fields (Feedback model)
- `merged_into_id` (UUID?) - Points to primary feedback if merged
- `merged_at` (Date?) - When the merge occurred
- `merged_feedback_ids` ([UUID]?) - For primary: IDs of merged feedback

### Migration
`AddFeedbackMergeFields` adds the merge-related columns to the feedbacks table.

## GitHub Integration

Push feedback items to GitHub as issues for tracking in your development workflow.

### Configuration Endpoint
`PATCH /projects/:id/github` (Bearer token + owner/admin required)

Request body:
```json
{
  "github_owner": "username-or-org",
  "github_repo": "repo-name",
  "github_token": "ghp_xxxxx",
  "github_default_labels": ["feedback", "user-request"],
  "github_sync_status": true
}
```

### Create Issue Endpoint
`POST /projects/:id/github/issue` (Bearer token + owner/admin required)

Request body:
```json
{
  "feedback_id": "uuid"
}
```

Response:
```json
{
  "feedback_id": "uuid",
  "issue_url": "https://github.com/owner/repo/issues/123",
  "issue_number": 123
}
```

### Bulk Create Issues Endpoint
`POST /projects/:id/github/issues` (Bearer token + owner/admin required)

Request body:
```json
{
  "feedback_ids": ["uuid", "uuid"]
}
```

Response:
```json
{
  "created": [{"feedback_id": "uuid", "issue_url": "...", "issue_number": 1}],
  "failed": ["uuid"]
}
```

### Database Fields

**Project model:**
- `github_owner` (String?) - Repository owner (user or org)
- `github_repo` (String?) - Repository name
- `github_token` (String?) - Personal Access Token
- `github_default_labels` ([String]?) - Labels to apply to all issues
- `github_sync_status` (Bool) - Sync feedback status to issue state

**Feedback model:**
- `github_issue_url` (String?) - URL of linked GitHub issue
- `github_issue_number` (Int?) - Issue number for API calls

### Status Sync
When `github_sync_status` is enabled:
- Feedback marked **completed** or **rejected** → GitHub issue closed
- Feedback changed from completed/rejected to another status → GitHub issue reopened

### GitHubService
Handles GitHub API interactions:
- `createIssue()` - Creates a new issue with formatted body
- `closeIssue()` - Closes an issue when feedback completed/rejected
- `reopenIssue()` - Reopens an issue when status changed back
- `buildIssueBody()` - Formats feedback details for issue body

### Migration
`AddProjectGitHubIntegration` adds GitHub fields to projects and feedbacks tables.
