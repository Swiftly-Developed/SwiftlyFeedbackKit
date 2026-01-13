//
//  OnboardingPaywallView.swift
//  SwiftlyFeedbackAdmin
//
//  Paywall step during onboarding with option to continue for free.
//

import SwiftUI
import RevenueCat

struct OnboardingPaywallView: View {
    let onContinue: () -> Void

    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isYearly = true
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Get the package for a specific tier and billing period
    private func package(for tier: SubscriptionTier, yearly: Bool, from offering: Offering) -> Package? {
        let productId: String
        switch tier {
        case .pro:
            productId = yearly ? SubscriptionService.ProductID.proYearly.rawValue : SubscriptionService.ProductID.proMonthly.rawValue
        case .team:
            productId = yearly ? SubscriptionService.ProductID.teamYearly.rawValue : SubscriptionService.ProductID.teamMonthly.rawValue
        case .free:
            return nil
        }
        return offering.availablePackages.first { $0.storeProduct.productIdentifier == productId }
    }

    /// The currently selected package based on tier and billing period
    private func selectedPackage(from offering: Offering) -> Package? {
        package(for: selectedTier, yearly: isYearly, from: offering)
    }

    var body: some View {
        paywallContent
        .task {
            await subscriptionService.fetchOfferings()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Paywall Content

    @ViewBuilder
    private var paywallContent: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: contentSpacing) {
                    Spacer(minLength: 16)

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.linearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        Text("Unlock More Features")
                            .font(titleFont)
                            .fontWeight(.bold)

                        Text("Choose a plan that works for you")
                            .font(subtitleFont)
                            .foregroundStyle(.secondary)
                    }

                    // Billing toggle
                    billingPeriodToggle
                        .padding(.horizontal, horizontalPadding)

                    // Feature comparison (compact)
                    compactFeatureComparison
                        .padding(.horizontal, horizontalPadding)

                    // Tier selection + pricing
                    if let offerings = subscriptionService.offerings,
                       let current = offerings.current {
                        tierSelectionSection(offering: current)
                            .padding(.horizontal, horizontalPadding)

                        // Subscribe button
                        subscribeSection(offering: current)
                            .padding(.horizontal, horizontalPadding)
                    } else if subscriptionService.isLoading {
                        ProgressView()
                            .padding()
                    }

                    Spacer(minLength: 16)
                }
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }

            // Fixed bottom buttons
            VStack(spacing: 8) {
                // Continue Free button
                Button {
                    onContinue()
                } label: {
                    Text("Continue with Free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                // Footer
                footerSection
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity)
            .background(bottomBackground)
        }
    }

    // MARK: - Billing Period Toggle

    @ViewBuilder
    private var billingPeriodToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isYearly = false
                }
            } label: {
                Text("Monthly")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isYearly ? Color.clear : Color.accentColor)
                    .foregroundStyle(isYearly ? Color.secondary : Color.white)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isYearly = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Yearly")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("-17%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(isYearly ? Color.white.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundStyle(isYearly ? .white : .green)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isYearly ? Color.accentColor : Color.clear)
                .foregroundStyle(isYearly ? .white : .secondary)
            }
            .buttonStyle(.plain)
        }
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Compact Feature Comparison

    @ViewBuilder
    private var compactFeatureComparison: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("FREE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
                    .frame(width: 44)
                Text("TEAM")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                    .frame(width: 44)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            CompactFeatureRow(feature: "Projects", free: "1", pro: "2", team: "∞")
            CompactFeatureRow(feature: "Feedback", free: "10", pro: "∞", team: "∞")
            CompactFeatureRow(feature: "Integrations", freeOK: false, proOK: true, teamOK: true)
            CompactFeatureRow(feature: "Team Members", freeOK: false, proOK: false, teamOK: true, isLast: true)
        }
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Tier Selection Section

    @ViewBuilder
    private func tierSelectionSection(offering: Offering) -> some View {
        HStack(spacing: 10) {
            OnboardingTierCard(
                tier: .pro,
                package: package(for: .pro, yearly: isYearly, from: offering),
                isSelected: selectedTier == .pro,
                isRecommended: true
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .pro
                }
            }

            OnboardingTierCard(
                tier: .team,
                package: package(for: .team, yearly: isYearly, from: offering),
                isSelected: selectedTier == .team,
                isRecommended: false
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .team
                }
            }
        }
    }

    // MARK: - Subscribe Section

    @ViewBuilder
    private func subscribeSection(offering: Offering) -> some View {
        let currentPackage = selectedPackage(from: offering)
        let tierColor: Color = selectedTier == .team ? .blue : .purple

        Button {
            Task {
                await purchasePackage(currentPackage)
            }
        } label: {
            HStack {
                if subscriptionService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text("Subscribe to \(selectedTier.displayName)")
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(currentPackage == nil ? Color.gray : tierColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(currentPackage == nil || subscriptionService.isLoading)
    }

    // MARK: - Footer Section

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task {
                    await restorePurchases()
                }
            }
            .font(.caption)
            .disabled(subscriptionService.isLoading)

            Text("Subscription auto-renews. Cancel anytime.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Link("Terms", destination: URL(string: "https://feedbackkit.app/terms")!)
                Link("Privacy", destination: URL(string: "https://feedbackkit.app/privacy")!)
            }
            .font(.caption2)
        }
    }

    // MARK: - Actions

    private func purchasePackage(_ package: Package?) async {
        guard let package else { return }

        do {
            try await subscriptionService.purchase(package: package)
            onContinue()
        } catch SubscriptionError.purchaseCancelled {
            // User cancelled - do nothing
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isProSubscriber {
                onContinue()
            } else {
                errorMessage = "No previous purchases found"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Platform-Adaptive Properties

    private var isCompactWidth: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var iconSize: CGFloat {
        #if os(macOS)
        return 40
        #else
        return isCompactWidth ? 36 : 44
        #endif
    }

    private var titleFont: Font {
        #if os(macOS)
        return .title2
        #else
        return isCompactWidth ? .title3 : .title2
        #endif
    }

    private var subtitleFont: Font {
        #if os(macOS)
        return .body
        #else
        return isCompactWidth ? .subheadline : .body
        #endif
    }

    private var contentSpacing: CGFloat {
        #if os(macOS)
        return 16
        #else
        return isCompactWidth ? 14 : 18
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        return isCompactWidth ? 20 : 32
        #endif
    }

    private var maxContentWidth: CGFloat {
        #if os(macOS)
        return 480
        #else
        return isCompactWidth ? .infinity : 520
        #endif
    }

    private var buttonMaxWidth: CGFloat {
        #if os(macOS)
        return 240
        #else
        return isCompactWidth ? .infinity : 280
        #endif
    }

    private var bottomPadding: CGFloat {
        #if os(macOS)
        return 20
        #else
        return isCompactWidth ? 12 : 20
        #endif
    }

    private var bottomBackground: some ShapeStyle {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

// MARK: - Compact Feature Row

private struct CompactFeatureRow: View {
    let feature: String
    var free: String?
    var pro: String?
    var team: String?
    var freeOK: Bool?
    var proOK: Bool?
    var teamOK: Bool?
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(feature)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                featureCell(text: free, isOK: freeOK, color: .secondary)
                    .frame(width: 44)
                featureCell(text: pro, isOK: proOK, color: .purple)
                    .frame(width: 44)
                featureCell(text: team, isOK: teamOK, color: .blue)
                    .frame(width: 44)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !isLast {
                Divider()
                    .padding(.leading, 12)
            }
        }
    }

    @ViewBuilder
    private func featureCell(text: String?, isOK: Bool?, color: Color) -> some View {
        if let text {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        } else if let isOK {
            Image(systemName: isOK ? "checkmark" : "xmark")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(isOK ? color : .secondary.opacity(0.4))
        }
    }
}

// MARK: - Onboarding Tier Card

private struct OnboardingTierCard: View {
    let tier: SubscriptionTier
    let package: Package?
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    private var tierColor: Color {
        tier == .team ? .blue : .purple
    }

    private var tierIcon: String {
        tier == .team ? "person.3.fill" : "crown.fill"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                if isRecommended {
                    Text("Popular")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierColor.opacity(0.2))
                        .foregroundStyle(tierColor)
                        .clipShape(Capsule())
                } else {
                    Text(" ")
                        .font(.caption2)
                        .padding(.vertical, 2)
                }

                Image(systemName: tierIcon)
                    .font(.title2)
                    .foregroundStyle(tierColor)

                Text(tier.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let package {
                    Text(priceText(for: package))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? tierColor : .secondary.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            #if os(iOS)
            .background(isSelected ? tierColor.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            #else
            .background(isSelected ? tierColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? tierColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func priceText(for package: Package) -> String {
        let price = package.storeProduct.localizedPriceString
        let productId = package.storeProduct.productIdentifier

        if productId.contains(".monthly") {
            return "\(price)/mo"
        } else if productId.contains(".yearly") {
            return "\(price)/yr"
        }

        switch package.packageType {
        case .monthly:
            return "\(price)/mo"
        case .annual:
            return "\(price)/yr"
        default:
            return price
        }
    }
}

#Preview("Paywall") {
    OnboardingPaywallView(onContinue: {})
}
