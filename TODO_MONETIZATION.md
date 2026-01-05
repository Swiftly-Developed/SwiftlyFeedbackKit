# Monetization Implementation - Remaining Tasks

This document tracks remaining work for the RevenueCat-based monetization system.

## Completed

### Admin App (Phase 3)

- [x] Add RevenueCat SDK dependency (Swift Package Manager)
- [x] Create `SubscriptionService.swift` with RevenueCat integration
- [x] Create `SubscriptionView.swift` with full subscription UI
- [x] Update `SettingsView.swift` with subscription section
- [x] Update `AuthViewModel.swift` with RevenueCat login/logout
- [x] Configure RevenueCat SDK at app launch in `SwiftlyFeedbackAdminApp.swift`
- [x] Add `subscription` category to `AppLogger`

---

## Remaining Tasks

### Phase 1: Server Foundation

#### Database Migration

Create `AddUserSubscriptionFields` migration to add subscription fields to User model:

```swift
// Fields to add to User model
subscriptionTier: SubscriptionTier      // .free, .pro, .team (default: .free)
subscriptionStatus: SubscriptionStatus? // .active, .expired, .cancelled, .gracePeriod
subscriptionProductId: String?          // RevenueCat product ID
subscriptionExpiresAt: Date?            // When subscription expires
revenueCatAppUserId: String?            // RevenueCat App User ID
subscriptionUpdatedAt: Date?            // Last subscription update timestamp
```

#### Enums

Add to server:

```swift
enum SubscriptionTier: String, Codable {
    case free, pro, team
}

enum SubscriptionStatus: String, Codable {
    case active, expired, cancelled, gracePeriod = "grace_period", paused
}
```

#### RevenueCat Service

Create `Sources/App/Services/RevenueCatService.swift`:
- Verify subscription status via RevenueCat REST API
- Map entitlements to tiers
- Verify webhook signatures

#### Webhook Controller

Create `Sources/App/Controllers/RevenueCatWebhookController.swift`:
- Handle `INITIAL_PURCHASE`, `RENEWAL`, `EXPIRATION`, `CANCELLATION`, `PRODUCT_CHANGE`, `BILLING_ISSUE`
- Update user subscription fields based on events

#### Subscription Endpoints

Add to `AuthController`:
- `GET /auth/subscription` - Get current user's subscription info and limits
- `POST /auth/subscription/sync` - Force sync with RevenueCat (called after purchase)

#### Environment Variables

```bash
REVENUECAT_API_KEY=sk_xxxxxxxxxxxx        # RevenueCat secret API key
REVENUECAT_WEBHOOK_SECRET=whsec_xxxxxxxx  # Webhook signature verification
```

---

### Phase 2: Server Feature Gating

#### Project Limits

Update `ProjectController.create()`:
- Check `user.subscriptionTier.maxProjects` before allowing creation
- Return 402 Payment Required if limit reached

#### Feedback Limits

Update `FeedbackController.create()`:
- Load project owner's subscription tier
- Check `tier.maxFeedbackPerProject` against current count
- Return 402 Payment Required if limit reached

#### Integration Gating

Update these endpoints to require Team tier:
- `PATCH /projects/:id/slack`
- `PATCH /projects/:id/github`
- `POST /projects/:id/invites`

Update `EmailService` to check subscription before sending notifications.

---

### Phase 3: Admin App Feature Gating UI

#### PaywallView

Create `Views/Subscription/PaywallView.swift`:
- Shows when user tries to access gated feature
- Displays feature comparison by tier
- Purchase buttons for upgrade

#### FeatureGatedView

Create `Views/Components/FeatureGatedView.swift`:
- Wrapper component for gated features
- Shows lock icon and dimmed content when access denied
- Presents PaywallView on tap

#### UI Updates

Update these views to use `FeatureGatedView`:
- `ProjectsView` - Gate "New Project" when at limit
- `ProjectDetailView` - Gate Slack, GitHub, Invite actions
- `FeedbackDashboardView` - Show feedback count with limit for Free tier

---

### Phase 4: SDK Updates

#### Error Handling

Update `SwiftlyFeedbackKit/Networking/APIClient.swift`:
- Handle 402 Payment Required responses
- Add `feedbackLimitReached` case to `SwiftlyFeedbackError`

#### User-Friendly Messages

Update SDK views to show friendly error when limits reached:
- Alert explaining the project owner needs to upgrade
- Don't show submit form if server returns limit error

---

### Phase 5: Testing & Polish

#### Server Tests

- [ ] Free user cannot create more than 1 project
- [ ] Pro user cannot create more than 2 projects
- [ ] Team user can create unlimited projects
- [ ] Free project rejects feedback after 10 items
- [ ] Slack/GitHub endpoints return 402 for non-Team users
- [ ] Webhook correctly updates user subscription

#### Admin App Tests

- [ ] Purchase flow completes
- [ ] Restore purchases works
- [ ] Feature gates show lock icons
- [ ] Paywall appears for gated features

#### SDK Tests

- [ ] Feedback submission shows error at limit

---

## RevenueCat Setup Checklist

### RevenueCat Dashboard

- [ ] Create project "SwiftlyFeedback"
- [ ] Add iOS/macOS apps with Bundle IDs
- [ ] Create entitlements: "Swiftly Pro", "Swiftly Team"
- [ ] Map products to entitlements

### App Store Connect

- [ ] Create subscription group "SwiftlyFeedback Subscriptions"
- [ ] Create products:
  - `swiftlyfeedback.pro.monthly` ($15)
  - `swiftlyfeedback.pro.yearly` ($150)
  - `swiftlyfeedback.team.monthly` ($39)
  - `swiftlyfeedback.team.yearly` ($390)

### Webhook Configuration

- [ ] Set webhook URL: `https://api.swiftlyfeedback.com/api/v1/webhooks/revenuecat`
- [ ] Copy webhook signing secret to server environment
- [ ] Enable all subscription events

---

## Reference

See `PLAN_MONETIZATION.md` (archived) for detailed implementation specs including:
- Full API response examples
- RevenueCat webhook payload examples
- Detailed DTO structures
- Security considerations
