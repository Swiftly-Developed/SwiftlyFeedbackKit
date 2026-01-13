# Subscription Service Environment Migration Plan

## Overview

This document outlines the migration from the broken `@State` pattern to `@Environment` for the `SubscriptionService` singleton. This fix will resolve the issue where purchases don't unlock features because views are observing stale data.

---

## Problem Summary

**Current (Broken):**
```swift
@State private var subscriptionService = SubscriptionService.shared
```

**Target (Fixed):**
```swift
@Environment(SubscriptionService.self) private var subscriptionService
```

---

## Migration Steps

### Phase 1: Update SubscriptionService for Environment Compatibility

**File:** `SwiftlyFeedbackAdmin/Services/SubscriptionService.swift`

The `SubscriptionService` class is already `@Observable`, which is compatible with SwiftUI's Environment. No changes needed to the service itself.

**Verification:**
```swift
@MainActor
@Observable
final class SubscriptionService: @unchecked Sendable {
    static let shared = SubscriptionService()
    // ...
}
```

---

### Phase 2: Inject SubscriptionService into Environment

**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdminApp.swift`

**Current Code (line 78-84):**
```swift
WindowGroup {
    RootView()
        .environment(deepLinkManager)
        .onOpenURL { url in
            deepLinkManager.handleURL(url)
        }
}
```

**Updated Code:**
```swift
WindowGroup {
    RootView()
        .environment(SubscriptionService.shared)
        .environment(deepLinkManager)
        .onOpenURL { url in
            deepLinkManager.handleURL(url)
        }
}
```

**Also update the Developer Center window (line 102-108):**
```swift
Window("Developer Center", id: "developer-center") {
    DeveloperCenterView(projectViewModel: developerCenterViewModel, isStandaloneWindow: true)
        .environment(SubscriptionService.shared)
        .frame(minWidth: 500, minHeight: 600)
        .task {
            await developerCenterViewModel.loadProjects()
        }
}
```

---

### Phase 3: Update All View Files

Each file below requires the same change pattern:

**Change:**
```swift
@State private var subscriptionService = SubscriptionService.shared
```

**To:**
```swift
@Environment(SubscriptionService.self) private var subscriptionService
```

#### 3.1 Settings Views

| File | Line | View/Struct Name |
|------|------|------------------|
| `Views/Settings/PaywallView.swift` | 15 | `PaywallView` |
| `Views/Settings/SubscriptionView.swift` | 11 | `SubscriptionView` |
| `Views/Settings/SettingsView.swift` | 8 | `SettingsView` |
| `Views/Settings/DeveloperCenterView.swift` | 31 | `DeveloperCenterView` |
| `Views/Settings/FeatureGatedView.swift` | 19 | `FeatureGatedView` |
| `Views/Settings/FeatureGatedView.swift` | 59 | `SubscriptionGatedButton` |
| `Views/Settings/FeatureGatedView.swift` | 82 | `TierBadgeModifier` |

#### 3.2 Onboarding Views

| File | Line | View/Struct Name |
|------|------|------------------|
| `Views/Onboarding/OnboardingPaywallView.swift` | 14 | `OnboardingPaywallView` |

#### 3.3 Project Views

| File | Line | View/Struct Name |
|------|------|------------------|
| `Views/Projects/ProjectListView.swift` | 34 | `ProjectListView` |
| `Views/Projects/ProjectDetailView.swift` | 24 | `ProjectDetailView` |
| `Views/Projects/ProjectMembersView.swift` | 11 | `ProjectMembersView` |

#### 3.4 Feedback Views

| File | Line | View/Struct Name |
|------|------|------------------|
| `Views/Feedback/FeedbackDashboardView.swift` | 32 | `FeedbackDashboardView` |
| `Views/Feedback/FeedbackListView.swift` | 1321 | `MRRBadge` (nested struct) |

#### 3.5 Users Views

| File | Line | View/Struct Name |
|------|------|------------------|
| `Views/Users/UsersListView.swift` | 101 | `MRRCell` (nested struct) |
| `Views/Users/UsersListView.swift` | 150 | `MRRBadgeView` (nested struct) |
| `Views/Users/UsersDashboardView.swift` | 230 | `MRRStatCard` (nested struct) |
| `Views/Users/UsersDashboardView.swift` | 328 | `UserMRRCell` (nested struct) |

---

### Phase 4: Handle Nested Structs and Modifiers

Some views have nested structs that also need the environment. These require special handling.

#### 4.1 FeatureGatedView.swift - Multiple Structs

This file has 3 separate structs that need updating:

```swift
// 1. FeatureGatedView (line 14-50)
struct FeatureGatedView<Content: View>: View {
    let requiredTier: SubscriptionTier
    let featureName: String
    @ViewBuilder let content: () -> Content

    @Environment(SubscriptionService.self) private var subscriptionService  // Changed
    @State private var showPaywall = false
    // ...
}

// 2. SubscriptionGatedButton (line 54-76)
struct SubscriptionGatedButton<Label: View>: View {
    let requiredTier: SubscriptionTier
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @Environment(SubscriptionService.self) private var subscriptionService  // Changed
    @State private var showPaywall = false
    // ...
}

// 3. TierBadgeModifier (line 79-99)
struct TierBadgeModifier: ViewModifier {
    let tier: SubscriptionTier

    @Environment(SubscriptionService.self) private var subscriptionService  // Changed
    // ...
}
```

#### 4.2 Nested Structs in List Views

For nested structs like `MRRBadge`, `MRRCell`, etc., the environment is automatically inherited from parent views. Just update the declaration:

**FeedbackListView.swift (line ~1321):**
```swift
struct MRRBadge: View {
    let mrr: Double?

    @Environment(SubscriptionService.self) private var subscriptionService
    // ...
}
```

**UsersListView.swift (lines 101, 150):**
```swift
struct MRRCell: View {
    // ...
    @Environment(SubscriptionService.self) private var subscriptionService
}

struct MRRBadgeView: View {
    // ...
    @Environment(SubscriptionService.self) private var subscriptionService
}
```

**UsersDashboardView.swift (lines 230, 328):**
```swift
struct MRRStatCard: View {
    // ...
    @Environment(SubscriptionService.self) private var subscriptionService
}

struct UserMRRCell: View {
    // ...
    @Environment(SubscriptionService.self) private var subscriptionService
}
```

---

### Phase 5: Update Preview Providers

All `#Preview` macros that use subscription-dependent views need the environment injected.

**Pattern:**
```swift
#Preview("Preview Name") {
    SomeView()
        .environment(SubscriptionService.shared)
}
```

**Files with Previews to Update:**

| File | Preview Names |
|------|---------------|
| `PaywallView.swift` | "Pro Required", "Team Required" |
| `SubscriptionView.swift` | "Free User" |
| `FeatureGatedView.swift` | "Locked Feature", "Unlocked Feature" |
| `OnboardingPaywallView.swift` | "Paywall" |

**Example - PaywallView.swift:**
```swift
#Preview("Pro Required") {
    PaywallView(requiredTier: .pro)
        .environment(SubscriptionService.shared)
}

#Preview("Team Required") {
    PaywallView(requiredTier: .team)
        .environment(SubscriptionService.shared)
}
```

---

### Phase 6: Handle Sheet Presentations

Views presented as sheets inherit environment from their presenting view. No special handling needed for:
- `PaywallView` presented via `.sheet(isPresented:)`
- `OnboardingPaywallView` in onboarding flow

**However**, ensure the presenting view has the environment. The environment injection at `RootView` level covers all cases.

---

### Phase 7: Verify AuthViewModel Integration

**File:** `SwiftlyFeedbackAdmin/ViewModels/AuthViewModel.swift`

The `AuthViewModel` calls `SubscriptionService.shared` directly (not via environment). This is **correct** and should NOT be changed:

```swift
// Lines 72, 128, 172, 231 - These are correct
await SubscriptionService.shared.login(userId: userId)

// Line 194 - This is correct
await SubscriptionService.shared.logout()
```

ViewModels are not SwiftUI views and cannot use `@Environment`. Direct singleton access in ViewModels is the correct pattern.

---

## Implementation Checklist

### Pre-Implementation
- [ ] Create a new git branch: `fix/subscription-environment-migration`
- [ ] Run existing tests to establish baseline

### Phase 1: SubscriptionService
- [ ] Verify `SubscriptionService` is `@Observable` (no changes needed)

### Phase 2: Environment Injection
- [ ] Update `SwiftlyFeedbackAdminApp.swift` - Main WindowGroup
- [ ] Update `SwiftlyFeedbackAdminApp.swift` - Developer Center Window (macOS)

### Phase 3: View Updates (17 changes across 13 files)
- [ ] `PaywallView.swift:15`
- [ ] `SubscriptionView.swift:11`
- [ ] `SettingsView.swift:8`
- [ ] `DeveloperCenterView.swift:31`
- [ ] `FeatureGatedView.swift:19` (FeatureGatedView)
- [ ] `FeatureGatedView.swift:59` (SubscriptionGatedButton)
- [ ] `FeatureGatedView.swift:82` (TierBadgeModifier)
- [ ] `OnboardingPaywallView.swift:14`
- [ ] `ProjectListView.swift:34`
- [ ] `ProjectDetailView.swift:24`
- [ ] `ProjectMembersView.swift:11`
- [ ] `FeedbackDashboardView.swift:32`
- [ ] `FeedbackListView.swift:1321` (MRRBadge)
- [ ] `UsersListView.swift:101` (MRRCell)
- [ ] `UsersListView.swift:150` (MRRBadgeView)
- [ ] `UsersDashboardView.swift:230` (MRRStatCard)
- [ ] `UsersDashboardView.swift:328` (UserMRRCell)

### Phase 4: Preview Updates
- [ ] `PaywallView.swift` - 2 previews
- [ ] `SubscriptionView.swift` - 1 preview
- [ ] `FeatureGatedView.swift` - 2 previews
- [ ] `OnboardingPaywallView.swift` - 1 preview

### Post-Implementation
- [ ] Build for iOS Simulator
- [ ] Build for macOS
- [ ] Run all tests
- [ ] Manual testing: Purchase flow in DEBUG
- [ ] Manual testing: Restore purchases
- [ ] Manual testing: Feature gating updates after purchase

---

## Detailed File Changes

### SwiftlyFeedbackAdminApp.swift

```swift
// Line 78-84: Add .environment(SubscriptionService.shared)
WindowGroup {
    RootView()
        .environment(SubscriptionService.shared)  // ADD THIS LINE
        .environment(deepLinkManager)
        .onOpenURL { url in
            deepLinkManager.handleURL(url)
        }
}

// Line 102-108: Add .environment(SubscriptionService.shared)
#if os(macOS)
Window("Developer Center", id: "developer-center") {
    DeveloperCenterView(projectViewModel: developerCenterViewModel, isStandaloneWindow: true)
        .environment(SubscriptionService.shared)  // ADD THIS LINE
        .frame(minWidth: 500, minHeight: 600)
        .task {
            await developerCenterViewModel.loadProjects()
        }
}
#endif
```

### PaywallView.swift

```swift
// Line 15: Change @State to @Environment
struct PaywallView: View {
    let requiredTier: SubscriptionTier

    @Environment(SubscriptionService.self) private var subscriptionService  // CHANGED
    @State private var selectedTier: SubscriptionTier = .pro
    // ... rest unchanged
}

// Line 584-590: Update previews
#Preview("Pro Required") {
    PaywallView(requiredTier: .pro)
        .environment(SubscriptionService.shared)  // ADD THIS
}

#Preview("Team Required") {
    PaywallView(requiredTier: .team)
        .environment(SubscriptionService.shared)  // ADD THIS
}
```

### FeatureGatedView.swift

```swift
// Line 19: FeatureGatedView
struct FeatureGatedView<Content: View>: View {
    let requiredTier: SubscriptionTier
    let featureName: String
    @ViewBuilder let content: () -> Content

    @Environment(SubscriptionService.self) private var subscriptionService  // CHANGED
    @State private var showPaywall = false
    // ...
}

// Line 59: SubscriptionGatedButton
struct SubscriptionGatedButton<Label: View>: View {
    let requiredTier: SubscriptionTier
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @Environment(SubscriptionService.self) private var subscriptionService  // CHANGED
    @State private var showPaywall = false
    // ...
}

// Line 82: TierBadgeModifier
struct TierBadgeModifier: ViewModifier {
    let tier: SubscriptionTier

    @Environment(SubscriptionService.self) private var subscriptionService  // CHANGED
    // ...
}

// Line 110-136: Update previews
#Preview("Locked Feature") {
    FeatureGatedView(requiredTier: .pro, featureName: "Pro Feature") {
        // ...
    }
    .environment(SubscriptionService.shared)  // ADD THIS
}

#Preview("Unlocked Feature") {
    FeatureGatedView(requiredTier: .free, featureName: "Free Feature") {
        // ...
    }
    .environment(SubscriptionService.shared)  // ADD THIS
}
```

### All Other Views (Same Pattern)

For each remaining file, apply the same transformation:

```swift
// BEFORE
@State private var subscriptionService = SubscriptionService.shared

// AFTER
@Environment(SubscriptionService.self) private var subscriptionService
```

---

## Testing Plan

### Build Verification
1. Build for iOS Simulator - should compile without errors
2. Build for macOS - should compile without errors

### Unit Tests
1. Run `DebugSettingsMigrationTests` - should pass
2. Run all Admin app tests

### Manual Testing Scenarios

#### Scenario 1: Purchase Flow (DEBUG)
1. Launch app with Free tier
2. Navigate to a Pro-gated feature
3. See paywall appear
4. Complete purchase (sandbox)
5. **Expected:** Feature unlocks immediately without paywall reappearing

#### Scenario 2: Restore Purchases
1. Launch app with Free tier (after previous purchase)
2. Go to Settings > Subscription
3. Tap "Restore Purchases"
4. **Expected:** Tier updates to Pro/Team, UI reflects change immediately

#### Scenario 3: Feature Gating Updates
1. Start with Free tier
2. Note locked features (integrations, team members, etc.)
3. Purchase Pro subscription
4. **Expected:** All Pro features unlock immediately
5. Navigate between tabs
6. **Expected:** Features remain unlocked

#### Scenario 4: Paywall Dismissal
1. Open paywall from any locked feature
2. Complete purchase
3. **Expected:** Paywall dismisses
4. **Expected:** Locked feature is now accessible
5. Navigate back to same feature
6. **Expected:** No paywall appears

---

## Rollback Plan

If issues are discovered after deployment:

1. Revert to previous pattern:
```swift
@State private var subscriptionService = SubscriptionService.shared
```

2. Remove environment injection from `SwiftlyFeedbackAdminApp.swift`

3. The app will work (with the original bug), allowing time to investigate

---

## Summary

| Category | Count |
|----------|-------|
| Files to modify | 14 |
| `@State` to `@Environment` changes | 17 |
| Preview updates | 6 |
| Environment injection points | 2 |

**Total estimated changes:** ~40 lines of code

**Risk level:** Low - This is a straightforward refactor with well-defined patterns. All changes are isolated to the view layer and don't affect business logic.

**Expected outcome:** Subscription purchases and restore will properly update the UI in real-time, resolving the "features don't unlock" bug.
