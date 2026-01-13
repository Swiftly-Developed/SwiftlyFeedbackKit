# Subscription System Simplification - Technical Report

## Executive Summary

This document details the changes made to simplify the SwiftlyFeedback Admin app's subscription and paywall system. The primary goals were to:

1. Remove TestFlight simulation functionality that was no longer needed
2. Remove "DEV: Unlock on Server" buttons that were causing confusion
3. Ensure subscription testing sections only appear in DEBUG builds
4. Create a cleaner separation between debug and production code paths

---

## Changes Made

### 1. Removed TestFlight Simulation (`BuildEnvironment.swift`)

**What was removed:**
- `simulateTestFlight` static property
- `initializeDebugSettings()` function
- Related UserDefaults checks for TestFlight simulation

**Why:**
The TestFlight simulation feature was designed to test TestFlight-specific behavior in DEBUG builds. However, it was causing confusion and the behavior can be tested by actually deploying to TestFlight.

**File:** `SwiftlyFeedbackAdmin/Utilities/BuildEnvironment.swift`

---

### 2. Removed Storage Keys (`StorageKey.swift`)

**Keys removed:**
- `disableEnvironmentOverride` - Was used to disable environment-based feature unlocking
- `simulateTestFlight` - Was used for TestFlight simulation in DEBUG builds

**Key retained:**
- `simulatedSubscriptionTier` - Still needed for DEBUG tier simulation in Developer Center

**File:** `SwiftlyFeedbackAdmin/Services/Storage/StorageKey.swift`

---

### 3. Removed DEV Unlock Buttons (`PaywallView.swift`, `OnboardingPaywallView.swift`)

**What was removed from both files:**
- `@State private var isOverridingTier` state variable
- `canUseServerOverride` computed property
- The entire "DEV: Unlock Team on Server" button block
- `overrideTierOnServer()` async function

**Why:**
These buttons were intended for quickly unlocking subscription tiers during development by calling the server's tier override endpoint. However:

1. They were wrapped in `#if DEBUG` but still appeared in DEBUG builds (by design)
2. The user repeatedly tried to remove them, indicating they weren't useful
3. The same functionality is available through Developer Center's subscription simulation

**Files:**
- `SwiftlyFeedbackAdmin/Views/Settings/PaywallView.swift`
- `SwiftlyFeedbackAdmin/Views/Onboarding/OnboardingPaywallView.swift`

---

### 4. Hidden Subscription Sections in Developer Center (`DeveloperCenterView.swift`)

**Sections wrapped in `#if DEBUG`:**
- `featureAccessSection` - Shows current tier, tier picker, and save/reset buttons
- `subscriptionSimulationSection` - Allows simulating different subscription tiers
- `resetPurchases()` function - Clears simulated tier and refreshes RevenueCat

**Why:**
These sections are only useful for developers testing subscription behavior. TestFlight testers should use real subscription flows (sandbox purchases) to test the actual user experience.

**File:** `SwiftlyFeedbackAdmin/Views/Settings/DeveloperCenterView.swift`

---

### 5. Removed Debug Settings Initialization (`SwiftlyFeedbackAdminApp.swift`)

**What was removed:**
```swift
#if DEBUG
BuildEnvironment.initializeDebugSettings()
#endif
```

**Why:**
This call was initializing debug settings from UserDefaults, which is no longer needed since TestFlight simulation was removed.

**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdminApp.swift`

---

### 6. Updated Tests (`DebugSettingsMigrationTests.swift`)

**Tests removed:**
- `testTestFlightSimulationPersistence()` - Tested TestFlight simulation persistence
- `testInitializeDebugSettings()` - Tested debug settings initialization

**Tests retained:**
- `testSimulatedTierPersistence()` - Tests tier simulation persistence
- `testDebugScope()` - Tests that debug settings use correct scope
- `testClearDebugSettings()` - Tests clearing debug settings

**File:** `SwiftlyFeedbackAdminTests/Services/DebugSettingsMigrationTests.swift`

---

## Current Subscription System Architecture

### Build Type → Feature Access

| Build Type | Environment | Subscription Source |
|------------|-------------|---------------------|
| DEBUG | Any | RevenueCat (real) or Simulated Tier |
| TestFlight | Any | RevenueCat (sandbox purchases) |
| App Store | Production | RevenueCat (real purchases) |

### Tier Priority Order

When determining `effectiveTier`, the system checks in this order:

1. **Simulated Tier** (DEBUG only) - Set via Developer Center
2. **Actual RevenueCat Tier** - From `currentTier` property

**Note:** The previous "Environment Override" that unlocked Team tier for non-production environments has been effectively disabled by removing the DEV unlock buttons.

### Feature Gating

Features are gated using:
```swift
subscriptionService.meetsRequirement(.pro)  // Checks effectiveTier
subscriptionService.meetsRequirement(.team) // Checks effectiveTier
```

Server also enforces tiers independently and returns 402 Payment Required when limits are exceeded.

---

## StoreKit Sandbox Testing

### Current Status

StoreKit sandbox purchases are showing as "cancelled by user" even when the user doesn't cancel.

### Possible Causes

1. **Sandbox Apple ID not signed in**
   - macOS: System Settings → App Store → Sandbox Account
   - iOS: Settings → App Store → Sandbox Account

2. **Products not approved in App Store Connect**
   - Products are in `READY_TO_SUBMIT` status
   - Need to be submitted for review and approved

3. **RevenueCat cache issues**
   - RevenueCat caches customer info
   - Use Developer Center's "Reset Purchases" in DEBUG builds

### RevenueCat Warnings (Benign)

```
⚠️ Couldn't find any products registered in RevenueCat
⚠️ There's an issue with your configuration
💰 Couldn't save CustomerInfoManager cache
```

These warnings appear because:
- Products aren't fully configured in App Store Connect yet
- Cache directories may not exist (RevenueCat handles this gracefully)

---

## Testing Subscription Features

### In DEBUG Builds

1. **Developer Center** (Cmd+Shift+D on macOS)
   - Use "Subscription Simulation" to set simulated tier
   - Use "Save Tier Override to Server" to sync with backend
   - Use "Reset Purchases" to clear simulation

2. **Sandbox Purchases**
   - Sign into Sandbox Apple ID
   - Make test purchases through normal paywall flow
   - Purchases will be sandbox transactions (not real charges)

### In TestFlight Builds

1. **Sandbox Purchases Only**
   - Developer Center subscription sections are hidden
   - Must use real StoreKit sandbox purchase flow
   - Sign into Sandbox Apple ID on device

### In App Store Builds

1. **Real Purchases Only**
   - All debug features removed
   - Real charges through App Store
   - RevenueCat handles subscription management

---

## File Summary

| File | Changes |
|------|---------|
| `BuildEnvironment.swift` | Removed TestFlight simulation |
| `StorageKey.swift` | Removed 2 unused keys |
| `PaywallView.swift` | Removed DEV unlock button |
| `OnboardingPaywallView.swift` | Removed DEV unlock button |
| `DeveloperCenterView.swift` | Wrapped subscription sections in `#if DEBUG` |
| `SwiftlyFeedbackAdminApp.swift` | Removed debug settings initialization |
| `DebugSettingsMigrationTests.swift` | Removed 2 obsolete tests |
| `CLAUDE.md` | Documentation updated |

---

## Recommendations

### Short Term

1. **Submit products for App Store review** - Products need approval before sandbox purchases work reliably

2. **Test with Sandbox Apple ID** - Ensure Sandbox account is signed in on test devices

3. **Use RevenueCat Dashboard** - Monitor subscription events and debug issues

### Long Term

1. **Consider StoreKit Testing in Xcode** - Use StoreKit Configuration files for offline testing

2. **Add subscription status logging** - More detailed logs during purchase flow

3. **Document sandbox testing setup** - Add setup guide for new developers

---

## Conclusion

The subscription system has been simplified by removing:
- TestFlight simulation functionality
- DEV unlock buttons from paywalls
- Debug subscription UI from non-DEBUG builds

The system now relies on:
- **DEBUG builds**: Tier simulation via Developer Center + sandbox purchases
- **TestFlight builds**: Sandbox purchases only (real StoreKit flow)
- **App Store builds**: Real purchases only

Current issue with sandbox purchases showing as "cancelled" is an environment configuration issue, not a code issue. Requires proper Sandbox Apple ID setup and App Store Connect product approval.
