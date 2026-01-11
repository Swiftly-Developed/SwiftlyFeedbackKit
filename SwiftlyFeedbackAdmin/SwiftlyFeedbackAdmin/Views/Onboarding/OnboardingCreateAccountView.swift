import SwiftUI

struct OnboardingCreateAccountView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onBack: () -> Void

    private enum Field: Hashable {
        case name, email, password, confirmPassword
    }

    @FocusState private var focusedField: Field?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: platformSpacing) {
                    Spacer(minLength: 16)

                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: iconBackgroundSize, height: iconBackgroundSize)

                            Image(systemName: "person.badge.plus")
                                .font(.system(size: iconSize))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .accessibilityHidden(true)
                        }

                        VStack(spacing: 4) {
                            Text("Create Your Account")
                                .font(titleFont)
                                .fontWeight(.bold)
                                .accessibilityAddTraits(.isHeader)

                            Text("Join thousands of developers collecting feedback")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 8)

                    // Form Fields - Use Form on macOS for native styling
                    #if os(macOS)
                    macOSFormFields
                    #else
                    iOSFormFields
                    #endif

                    // Password Strength Indicator
                    if !viewModel.signupPassword.isEmpty {
                        PasswordStrengthView(
                            password: viewModel.signupPassword,
                            showPasswordMatch: true,
                            confirmPassword: viewModel.signupConfirmPassword
                        )
                        .padding(.horizontal, isCompactWidth ? 0 : 16)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }

            // Fixed bottom buttons
            VStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.createAccount()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: buttonMaxWidth)
                            .frame(minHeight: 44)
                    } else {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: buttonMaxWidth)
                            .frame(minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.isSignupValid || viewModel.isLoading)
                .accessibilityHint(viewModel.isSignupValid ? "Create your account" : "Fill in all fields to continue")

                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .accessibilityLabel("Go back to welcome screen")
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity)
            .background(bottomBackground)
        }
        .onAppear {
            #if os(iOS)
            focusedField = .name
            #endif
        }
    }

    // MARK: - iOS Form Fields

    #if os(iOS)
    private var iOSFormFields: some View {
        VStack(spacing: 16) {
            OnboardingTextField(
                label: "Name",
                placeholder: "Your name",
                text: $viewModel.signupName,
                contentType: .name,
                keyboardType: .default,
                autocapitalization: .words,
                isFocused: focusedField == .name,
                onFocus: { focusedField = .name },
                onSubmit: { focusedField = .email },
                submitLabel: .next
            )
            .focused($focusedField, equals: .name)

            OnboardingTextField(
                label: "Email",
                placeholder: "your@email.com",
                text: $viewModel.signupEmail,
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                isFocused: focusedField == .email,
                onFocus: { focusedField = .email },
                onSubmit: { focusedField = .password },
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)

            OnboardingSecureField(
                label: "Password",
                placeholder: "At least 8 characters",
                text: $viewModel.signupPassword,
                errorMessage: viewModel.signupPassword.isEmpty || viewModel.signupPassword.count >= 8
                    ? nil : "Password must be at least 8 characters",
                isFocused: focusedField == .password,
                onFocus: { focusedField = .password },
                onSubmit: { focusedField = .confirmPassword },
                submitLabel: .next
            )
            .focused($focusedField, equals: .password)

            OnboardingSecureField(
                label: "Confirm Password",
                placeholder: "Re-enter your password",
                text: $viewModel.signupConfirmPassword,
                errorMessage: viewModel.signupConfirmPassword.isEmpty || viewModel.signupPassword == viewModel.signupConfirmPassword
                    ? nil : "Passwords do not match",
                isFocused: focusedField == .confirmPassword,
                onFocus: { focusedField = .confirmPassword },
                onSubmit: {
                    if viewModel.isSignupValid {
                        Task { await viewModel.createAccount() }
                    }
                },
                submitLabel: .go
            )
            .focused($focusedField, equals: .confirmPassword)
        }
    }
    #endif

    // MARK: - macOS Form Fields

    #if os(macOS)
    private var macOSFormFields: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $viewModel.signupName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("your@email.com", text: $viewModel.signupEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                SecureField("At least 8 characters", text: $viewModel.signupPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                if !viewModel.signupPassword.isEmpty && viewModel.signupPassword.count < 8 {
                    ValidationMessage(text: "Password must be at least 8 characters", type: .warning)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                SecureField("Re-enter your password", text: $viewModel.signupConfirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                if !viewModel.signupConfirmPassword.isEmpty &&
                    viewModel.signupPassword != viewModel.signupConfirmPassword {
                    ValidationMessage(text: "Passwords do not match", type: .error)
                }
            }
        }
    }
    #endif

    // MARK: - Platform-Adaptive Properties

    private var isCompactWidth: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var iconBackgroundSize: CGFloat {
        #if os(macOS)
        return 64
        #else
        return isCompactWidth ? 64 : 80
        #endif
    }

    private var iconSize: CGFloat {
        #if os(macOS)
        return 28
        #else
        return isCompactWidth ? 28 : 36
        #endif
    }

    private var titleFont: Font {
        #if os(macOS)
        return .title2
        #else
        return isCompactWidth ? .title3 : .title2
        #endif
    }

    private var platformSpacing: CGFloat {
        #if os(macOS)
        return 16
        #else
        return isCompactWidth ? 16 : 20
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 40
        #else
        return isCompactWidth ? 24 : 40
        #endif
    }

    private var maxContentWidth: CGFloat {
        #if os(macOS)
        return 420
        #else
        return isCompactWidth ? .infinity : 480
        #endif
    }

    private var buttonMaxWidth: CGFloat {
        #if os(macOS)
        return 280
        #else
        return isCompactWidth ? .infinity : 320
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

// MARK: - Reusable Form Components

#if os(iOS)
private struct OnboardingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isFocused: Bool = false
    var onFocus: () -> Void = {}
    var onSubmit: () -> Void = {}
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .onSubmit(onSubmit)
                .submitLabel(submitLabel)
                .accessibilityLabel(label)
        }
    }
}

private struct OnboardingSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String?
    var isFocused: Bool = false
    var onFocus: () -> Void = {}
    var onSubmit: () -> Void = {}
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .onSubmit(onSubmit)
                .submitLabel(submitLabel)
                .accessibilityLabel(label)

            if let error = errorMessage {
                ValidationMessage(text: error, type: .warning)
            }
        }
    }
}
#endif

private struct ValidationMessage: View {
    enum MessageType {
        case warning, error
    }

    let text: String
    let type: MessageType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(type == .error ? .red : .orange)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type == .error ? "Error" : "Warning"): \(text)")
    }
}

#Preview("iPhone") {
    OnboardingCreateAccountView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onBack: {}
    )
}

#Preview("iPad") {
    OnboardingCreateAccountView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onBack: {}
    )
}
