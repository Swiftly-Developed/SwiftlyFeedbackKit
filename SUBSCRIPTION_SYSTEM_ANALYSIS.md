# Subscription System Technical Analysis

## Executive Summary

**Problem:** Purchases made in DEV or TestFlight environments do not unlock features. The paywall continues to appear even after successful purchase or restore.

**Root Cause:** The subscription system has a **critical architectural flaw** where views use `@State private var subscriptionService = SubscriptionService.shared` to reference the subscription service. This pattern **breaks SwiftUI's reactivity** with `@Observable` objects, causing the UI to not update when subscription status changes.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Critical Bug Analysis](#critical-bug-analysis)
3. [Code Flow Analysis](#code-flow-analysis)
4. [Affected Files](#affected-files)
5. [RevenueCat Integration](#revenuecat-integration)
6. [Recommended Fixes](#recommended-fixes)

---

## Architecture Overview

### Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SwiftlyFeedbackAdminApp                            │
│                                                                              │
│  init() {                                                                    │
│      SubscriptionService.shared.configure()  ← RevenueCat initialized       │
│  }                                                                           │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SubscriptionService                                │
│                      (@MainActor @Observable singleton)                      │
│                                                                              │
│  Properties:                                                                 │
│  - customerInfo: CustomerInfo?     ← Updated after purchase/restore         │
│  - offerings: Offerings?           ← Available packages from RevenueCat     │
│  - currentTier: SubscriptionTier   ← Computed from customerInfo             │
│  - effectiveTier: SubscriptionTier ← Considers simulation (DEBUG only)      │
│                                                                              │
│  Methods:                                                                    │
│  - configure(userId:)              ← Called at app launch                   │
│  - login(userId:)                  ← Called after user auth                 │
│  - purchase(package:)              ← Updates customerInfo                   │
│  - restorePurchases()              ← Updates customerInfo                   │
│  - fetchCustomerInfo()             ← Refreshes customerInfo                 │
│  - fetchOfferings()                ← Gets available packages                │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
            ▼                      ▼                      ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────────────────┐
│   PaywallView     │  │OnboardingPaywall  │  │    FeatureGatedView           │
│                   │  │     View          │  │                               │
│ @State private    │  │ @State private    │  │ @State private                │
│ var subscription  │  │ var subscription  │  │ var subscriptionService =     │
│ Service =         │  │ Service =         │  │ SubscriptionService.shared    │
│ Subscription      │  │ Subscription      │  │                               │
│ Service.shared    │  │ Service.shared    │  │ if subscriptionService        │
│                   │  │                   │  │   .meetsRequirement(.pro)     │
│ ❌ BREAKS         │  │ ❌ BREAKS         │  │ ❌ NEVER UPDATES              │
│   REACTIVITY      │  │   REACTIVITY      │  │                               │
└───────────────────┘  └───────────────────┘  └───────────────────────────────┘
```

### Subscription Tiers

| Tier | Entitlement ID | Features |
|------|----------------|----------|
| Free | (none) | 1 project, 10 feedback/project |
| Pro | "Swiftly Pro" | 2 projects, unlimited feedback, integrations |
| Team | "Swiftly Team" | Unlimited projects, team members, voter notifications |

### Product IDs

| Product | RevenueCat Product ID |
|---------|----------------------|
| Pro Monthly | `swiftlyfeedback.pro.monthly` |
| Pro Yearly | `swiftlyfeedback.pro.yearly` |
| Team Monthly | `swiftlyfeedback.team.monthly` |
| Team Yearly | `swiftlyfeedback.team.yearly` |

---

## Critical Bug Analysis

### Bug #1: @State Breaks @Observable Reactivity

**Location:** Multiple view files

**The Pattern (BROKEN):**
```swift
struct PaywallView: View {
    @State private var subscriptionService = SubscriptionService.shared  // ❌ BUG
    // ...
}
```

**Why This Is Wrong:**

1. `SubscriptionService` is marked `@Observable` (line 79 of SubscriptionService.swift)
2. When a view declares `@State private var subscriptionService = SubscriptionService.shared`:
   - SwiftUI creates a **copy of the reference** at view initialization time
   - The `@State` wrapper manages this copy independently
   - Changes to `SubscriptionService.shared.customerInfo` do NOT trigger view updates
   - The view's captured reference is effectively "frozen"

3. Even though `SubscriptionService` is a singleton and `@Observable`, the `@State` wrapper breaks the observation chain.

**Correct Pattern:**
```swift
struct PaywallView: View {
    let subscriptionService = SubscriptionService.shared  // ✅ Direct reference
    // OR
    @Environment(SubscriptionService.self) var subscriptionService  // ✅ Environment
    // ...
}
```

**Impact:**
- After `purchase()` completes and updates `customerInfo`, views don't see the change
- After `restorePurchases()` completes, views don't see the change
- The paywall dismisses (because `purchase()` returned successfully), but...
- When any feature-gated view re-checks `subscriptionService.meetsRequirement()`, it still sees the OLD tier
- User sees the paywall again

### Bug #2: Purchase Flow Doesn't Verify Update Propagation

**Location:** `PaywallView.swift` lines 381-393, `OnboardingPaywallView.swift` lines 318-330

```swift
private func purchasePackage(_ package: Package?) async {
    guard let package else { return }

    do {
        try await subscriptionService.purchase(package: package)
        dismiss()  // ← Dismisses immediately without verifying tier updated
    } catch SubscriptionError.purchaseCancelled {
        // User cancelled - do nothing
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

**Problems:**
1. Dismisses immediately after `purchase()` returns
2. Never verifies that `effectiveTier` actually changed
3. Due to Bug #1, the view's reference may still show the old tier

### Bug #3: Restore Purchases Checks Stale Data

**Location:** `PaywallView.swift` lines 395-408

```swift
private func restorePurchases() async {
    do {
        try await subscriptionService.restorePurchases()
        if subscriptionService.isProSubscriber {  // ← Reads from @State captured copy
            dismiss()
        } else {
            errorMessage = "No previous purchases found"
            showError = true
        }
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

**Problem:**
- `restorePurchases()` updates `SubscriptionService.shared.customerInfo`
- But `subscriptionService.isProSubscriber` reads from the view's `@State` copy
- The `@State` copy wasn't updated, so it still shows `false`
- User sees "No previous purchases found" even when restore succeeded

---

## Code Flow Analysis

### 1. App Initialization

**File:** `SwiftlyFeedbackAdminApp.swift:67-74`

```swift
init() {
    // Configure subscription service at app launch
    SubscriptionService.shared.configure()  // ← No user ID yet

    // Configure SwiftlyFeedbackKit SDK...
    AppConfiguration.shared.configureSDK()
}
```

**`configure()` in SubscriptionService.swift:229-240:**
```swift
func configure(userId: UUID? = nil) {
    Purchases.logLevel = .debug
    Purchases.configure(withAPIKey: Self.revenueCatAPIKey)  // ← RevenueCat SDK initialized
    AppLogger.subscription.info("RevenueCat configured")

    if let userId {
        Task {
            await login(userId: userId)  // ← Only called if userId provided
        }
    }
}
```

**Issue:** At app launch, no user ID is available. RevenueCat creates an anonymous customer profile.

### 2. User Login

**File:** `AuthViewModel.swift:72, 128, 172, 231`

After successful login/signup:
```swift
// Sync subscription service with user ID
await SubscriptionService.shared.login(userId: response.user.id)
```

**`login(userId:)` in SubscriptionService.swift:245-258:**
```swift
func login(userId: UUID) async {
    AppLogger.subscription.info("Logging in to RevenueCat with user ID: \(userId)")

    do {
        let (customerInfo, _) = try await Purchases.shared.logIn(userId.uuidString)
        self.customerInfo = customerInfo  // ← Updates customerInfo
        AppLogger.subscription.info("RevenueCat login successful, tier: \(currentTier.displayName)")

        await syncWithServer()
    } catch {
        AppLogger.subscription.error("RevenueCat login failed: \(error)")
    }
}
```

### 3. Paywall Display

**File:** `PaywallView.swift:68-74`

```swift
.task {
    await subscriptionService.fetchOfferings()  // ← Fetches available packages
    // Pre-select required tier if it's Team
    if requiredTier == .team {
        selectedTier = .team
    }
}
```

### 4. Purchase Attempt

**File:** `PaywallView.swift:381-393`

```swift
private func purchasePackage(_ package: Package?) async {
    guard let package else { return }

    do {
        try await subscriptionService.purchase(package: package)
        dismiss()  // ← Problem: dismisses immediately
    } catch SubscriptionError.purchaseCancelled {
        // User cancelled - do nothing
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

**`purchase(package:)` in SubscriptionService.swift:306-340:**
```swift
func purchase(package: Package) async throws {
    isLoading = true
    defer { isLoading = false }

    AppLogger.subscription.info("Starting purchase for package: \(package.identifier)")

    do {
        let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

        if userCancelled {
            AppLogger.subscription.info("Purchase cancelled by user")
            throw SubscriptionError.purchaseCancelled
        }

        self.customerInfo = customerInfo  // ← Updates SubscriptionService.shared.customerInfo
        AppLogger.subscription.info("Purchase successful, tier: \(currentTier.displayName)")

        await syncWithServer()  // ← Syncs with backend
    } catch SubscriptionError.purchaseCancelled {
        throw SubscriptionError.purchaseCancelled
    } catch let error as ErrorCode {
        // ... error handling
    }
}
```

**The Problem Flow:**

1. User taps "Subscribe to Pro"
2. `purchasePackage()` calls `subscriptionService.purchase(package:)`
3. `purchase()` calls RevenueCat's `Purchases.shared.purchase()`
4. StoreKit shows payment sheet, user confirms
5. RevenueCat returns with updated `customerInfo` showing Pro entitlement
6. `purchase()` sets `self.customerInfo = customerInfo` on `SubscriptionService.shared`
7. `purchase()` returns successfully
8. `purchasePackage()` calls `dismiss()`
9. PaywallView dismisses
10. User is back on the feature they tried to access
11. `FeatureGatedView` checks `subscriptionService.meetsRequirement(.pro)`
12. **BUG:** `FeatureGatedView`'s `@State` reference still has old `customerInfo`
13. `meetsRequirement(.pro)` returns `false`
14. User sees the lock overlay or paywall again

---

## Affected Files

### Files Using Broken @State Pattern

| File | Line | Code |
|------|------|------|
| `PaywallView.swift` | 15 | `@State private var subscriptionService = SubscriptionService.shared` |
| `OnboardingPaywallView.swift` | 14 | `@State private var subscriptionService = SubscriptionService.shared` |
| `FeatureGatedView.swift` | 19 | `@State private var subscriptionService = SubscriptionService.shared` |
| `FeatureGatedView.swift` | 59 | `@State private var subscriptionService = SubscriptionService.shared` (SubscriptionGatedButton) |
| `FeatureGatedView.swift` | 82 | `@State private var subscriptionService = SubscriptionService.shared` (TierBadgeModifier) |
| `SubscriptionView.swift` | 11 | `@State private var subscriptionService = SubscriptionService.shared` |
| `DeveloperCenterView.swift` | 31 | `@State private var subscriptionService = SubscriptionService.shared` |

### Additional Files to Check

These files may also use the pattern and need verification:
- `ProjectMembersView.swift`
- `ProjectListView.swift`
- `ProjectDetailView.swift`
- `FeedbackDashboardView.swift`
- `FeedbackListView.swift`
- `UsersListView.swift`
- `UsersDashboardView.swift`
- All integration settings views (Slack, GitHub, Notion, etc.)

---

## RevenueCat Integration

### Configuration

**File:** `SubscriptionService.swift:89-103`

```swift
/// RevenueCat public API key
static let revenueCatAPIKey = "appl_qwlqUlehsPfFfhvmaWLAqfEKMGs"

/// Entitlement identifiers (must match RevenueCat dashboard)
static let proEntitlementID = "Swiftly Pro"
static let teamEntitlementID = "Swiftly Team"

/// Product identifiers
enum ProductID: String, CaseIterable {
    case proMonthly = "swiftlyfeedback.pro.monthly"
    case proYearly = "swiftlyfeedback.pro.yearly"
    case teamMonthly = "swiftlyfeedback.team.monthly"
    case teamYearly = "swiftlyfeedback.team.yearly"
}
```

### Tier Determination

**File:** `SubscriptionService.swift:156-171`

```swift
/// The user's current subscription tier based on RevenueCat entitlements
var currentTier: SubscriptionTier {
    guard let customerInfo else { return .free }

    // Check Team first (higher tier)
    if customerInfo.entitlements[Self.teamEntitlementID]?.isActive == true {
        return .team
    }

    // Check for Pro entitlement
    if customerInfo.entitlements[Self.proEntitlementID]?.isActive == true {
        return .pro
    }

    return .free
}
```

**This logic is correct.** The problem is not how the tier is determined, but how views access it.

### Server Sync

**File:** `SubscriptionService.swift:364-379`

```swift
private func syncWithServer() async {
    AppLogger.subscription.info("Syncing subscription with server")

    do {
        let _: EmptyResponse = try await AdminAPIClient.shared.post(
            path: "auth/subscription/sync",
            body: ["revenuecat_app_user_id": Purchases.shared.appUserID],
            requiresAuth: true
        )
        AppLogger.subscription.info("Subscription synced with server")
    } catch {
        AppLogger.subscription.error("Failed to sync subscription with server: \(error)")
        // Don't throw - this is a best-effort sync
    }
}
```

**Note:** This syncs the subscription to the server but doesn't return/update anything on the client. The server stores the user's tier for server-side enforcement.

---

## Recommended Fixes

### Fix #1: Remove @State from SubscriptionService References

**Change this (in ALL affected files):**
```swift
@State private var subscriptionService = SubscriptionService.shared
```

**To this:**
```swift
private let subscriptionService = SubscriptionService.shared
```

Or better, use SwiftUI Environment:

**In App:**
```swift
@main
struct SwiftlyFeedbackAdminApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(SubscriptionService.shared)
        }
    }
}
```

**In Views:**
```swift
@Environment(SubscriptionService.self) private var subscriptionService
```

### Fix #2: Add Post-Purchase Verification

In `PaywallView.swift`:

```swift
private func purchasePackage(_ package: Package?) async {
    guard let package else { return }

    do {
        try await subscriptionService.purchase(package: package)

        // Verify the tier actually updated
        await subscriptionService.fetchCustomerInfo()

        if subscriptionService.meetsRequirement(requiredTier) {
            dismiss()
        } else {
            // Purchase succeeded but tier didn't update - unusual case
            errorMessage = "Purchase completed. Please restart the app if features aren't unlocked."
            showError = true
        }
    } catch SubscriptionError.purchaseCancelled {
        // User cancelled - do nothing
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

### Fix #3: Add PurchasesDelegate for Real-Time Updates

Implement `PurchasesDelegate` to receive real-time updates:

```swift
extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            AppLogger.subscription.info("Customer info updated via delegate, tier: \(self.currentTier.displayName)")
        }
    }
}
```

And in `configure()`:
```swift
func configure(userId: UUID? = nil) {
    Purchases.logLevel = .debug
    Purchases.configure(withAPIKey: Self.revenueCatAPIKey)
    Purchases.shared.delegate = self  // ← Add this
    // ...
}
```

### Fix #4: Add Refresh After Restore

In `PaywallView.swift`:

```swift
private func restorePurchases() async {
    do {
        try await subscriptionService.restorePurchases()

        // Force refresh to ensure we have latest data
        await subscriptionService.fetchCustomerInfo()

        if subscriptionService.isProSubscriber {
            dismiss()
        } else {
            errorMessage = "No previous purchases found"
            showError = true
        }
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

---

## Testing Checklist

After implementing fixes, verify:

1. [ ] Purchase Pro subscription in DEBUG → features unlock immediately
2. [ ] Purchase Team subscription in DEBUG → features unlock immediately
3. [ ] Purchase in TestFlight (sandbox) → features unlock immediately
4. [ ] Restore purchases → previously purchased tier is restored
5. [ ] Feature-gated views update without app restart
6. [ ] Paywall doesn't reappear after successful purchase
7. [ ] Tier badge disappears after purchasing required tier
8. [ ] Server receives sync after purchase (check server logs)

---

## Summary

| Issue | Severity | Root Cause | Fix |
|-------|----------|------------|-----|
| `@State` breaks reactivity | **CRITICAL** | SwiftUI pattern misuse | Remove `@State`, use direct reference or `@Environment` |
| No post-purchase verification | HIGH | Missing validation | Add tier check after purchase |
| Restore checks stale data | HIGH | Same as #1 | Same as #1 |
| No real-time updates | MEDIUM | Missing delegate | Implement `PurchasesDelegate` |

**Primary Fix Required:** Replace all `@State private var subscriptionService = SubscriptionService.shared` with `private let subscriptionService = SubscriptionService.shared` or use `@Environment`.

This is a **data binding architecture issue**, not a RevenueCat issue. RevenueCat correctly returns updated customer info, but the views are looking at stale copies.
