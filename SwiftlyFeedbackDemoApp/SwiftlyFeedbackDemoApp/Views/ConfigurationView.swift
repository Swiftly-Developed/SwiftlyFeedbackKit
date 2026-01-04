import SwiftUI

struct ConfigurationView: View {
    var settings: AppSettings

    var body: some View {
        List {
            userSection
            subscriptionSection
            sdkConfigurationSection
            displayOptionsSection
        }
        .navigationTitle("Settings")
    }

    // MARK: - User Section

    @ViewBuilder
    private var userSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.userName.isEmpty ? "Anonymous User" : settings.userName)
                        .font(.headline)

                    Text(settings.userEmail.isEmpty ? "No email set" : settings.userEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            TextField("Your Name", text: Bindable(settings).userName)
                .textContentType(.name)
                .autocorrectionDisabled()

            TextField("Email Address", text: Bindable(settings).userEmail)
                .textContentType(.emailAddress)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            TextField("Custom User ID (optional)", text: Bindable(settings).customUserId)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        } header: {
            Text("Profile")
        } footer: {
            Text("Your email is used when submitting feedback so we can notify you of updates. Custom User ID links feedback to your account system.")
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            HStack {
                Text("Amount")
                Spacer()
                TextField("0.00", value: Bindable(settings).subscriptionAmount, format: .currency(code: "USD"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            Picker("Billing Cycle", selection: Bindable(settings).subscriptionType) {
                ForEach(SubscriptionType.allCases) { type in
                    Text(type.displayName).tag(type as SubscriptionType)
                }
            }

            if settings.subscriptionAmount > 0 && settings.subscriptionType != .none {
                HStack {
                    Text("Monthly MRR")
                    Spacer()
                    Text(calculatedMRR, format: .currency(code: "USD"))
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }
            }
        } header: {
            Text("Subscription")
        } footer: {
            Text("Optional: Set your subscription details for MRR tracking. This helps app developers understand which users are most valuable.")
        }
    }

    private var calculatedMRR: Double {
        switch settings.subscriptionType {
        case .none: return 0
        case .weekly: return settings.subscriptionAmount * (52.0 / 12.0)
        case .monthly: return settings.subscriptionAmount
        case .quarterly: return settings.subscriptionAmount / 3.0
        case .yearly: return settings.subscriptionAmount / 12.0
        }
    }

    // MARK: - SDK Configuration Section

    @ViewBuilder
    private var sdkConfigurationSection: some View {
        Section {
            Toggle("Allow Undo Vote", isOn: Bindable(settings).allowUndoVote)

            Toggle("Show Comment Section", isOn: Bindable(settings).showCommentSection)

            Toggle("Show Email Field", isOn: Bindable(settings).showEmailField)
        } header: {
            Text("Features")
        } footer: {
            Text("Configure which features are enabled in the feedback interface.")
        }
    }

    // MARK: - Display Options Section

    @ViewBuilder
    private var displayOptionsSection: some View {
        Section {
            Toggle("Show Status Badge", isOn: Bindable(settings).showStatusBadge)

            Toggle("Show Category Badge", isOn: Bindable(settings).showCategoryBadge)

            Toggle("Show Vote Count", isOn: Bindable(settings).showVoteCount)

            Toggle("Expand Description in List", isOn: Bindable(settings).expandDescriptionInList)
        } header: {
            Text("Display Options")
        } footer: {
            Text("Customize how feedback items are displayed in the list.")
        }
    }
}

#Preview {
    ConfigurationView(settings: AppSettings())
}
