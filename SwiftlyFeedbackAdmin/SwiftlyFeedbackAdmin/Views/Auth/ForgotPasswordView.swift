import SwiftUI

struct ForgotPasswordView: View {
    @Bindable var viewModel: AuthViewModel
    let onBackToLogin: () -> Void
    let onPasswordReset: () -> Void

    @State private var resendCooldown = 0
    @State private var timer: Timer?

    private enum ResetField: Hashable {
        case email, code, newPassword, confirmPassword
    }

    @FocusState private var focusedField: ResetField?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(viewModel.resetEmailSent
                     ? "Enter the code we sent to your email"
                     : "Enter your email to receive a reset code")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

            // Form
            if viewModel.resetEmailSent {
                resetCodeForm
            } else {
                emailForm
            }

            // Back to login
            Button("Back to Login") {
                viewModel.clearResetState()
                onBackToLogin()
            }
            .font(.subheadline)
        }
        .padding(32)
        .frame(maxWidth: 400)
        .onAppear {
            focusedField = viewModel.resetEmailSent ? .code : .email
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var emailForm: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $viewModel.resetEmail)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: .email)
                .onSubmit {
                    Task { await viewModel.requestPasswordReset() }
                }
                .submitLabel(.send)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif

            Button {
                Task {
                    await viewModel.requestPasswordReset()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Send Reset Code")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading || viewModel.resetEmail.isEmpty)
        }
    }

    private var resetCodeForm: some View {
        VStack(spacing: 16) {
            TextField("Reset Code", text: $viewModel.resetCode)
                .textFieldStyle(.roundedBorder)
                .textContentType(.oneTimeCode)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .code)
                .onSubmit { focusedField = .newPassword }
                .submitLabel(.next)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .multilineTextAlignment(.center)
                .font(Font.title2.monospaced())

            SecureField("New Password", text: $viewModel.resetNewPassword)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .newPassword)
                .onSubmit { focusedField = .confirmPassword }
                .submitLabel(.next)

            SecureField("Confirm Password", text: $viewModel.resetConfirmPassword)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmPassword)
                .onSubmit {
                    Task { await resetPassword() }
                }
                .submitLabel(.go)

            passwordRequirements

            Button {
                Task { await resetPassword() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Reset Password")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading || !canSubmit)

            resendCodeButton
        }
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            requirementRow(
                met: viewModel.resetNewPassword.count >= 8,
                text: "At least 8 characters"
            )
            requirementRow(
                met: !viewModel.resetNewPassword.isEmpty && viewModel.resetNewPassword == viewModel.resetConfirmPassword,
                text: "Passwords match"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }

    private var resendCodeButton: some View {
        VStack(spacing: 8) {
            Text("Didn't receive the code?")
                .foregroundStyle(.secondary)
                .font(.caption)

            Button {
                Task {
                    await viewModel.requestPasswordReset()
                    startResendCooldown()
                }
            } label: {
                if resendCooldown > 0 {
                    Text("Resend in \(resendCooldown)s")
                } else {
                    Text("Resend Code")
                }
            }
            .font(.subheadline)
            .disabled(viewModel.isLoading || resendCooldown > 0)
        }
        .padding(.top, 8)
    }

    private var canSubmit: Bool {
        viewModel.resetCode.count == 8 &&
        viewModel.resetNewPassword.count >= 8 &&
        viewModel.resetNewPassword == viewModel.resetConfirmPassword
    }

    private func resetPassword() async {
        let success = await viewModel.resetPassword()
        if success {
            onPasswordReset()
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

#Preview("Email Entry") {
    ForgotPasswordView(viewModel: AuthViewModel(), onBackToLogin: {}, onPasswordReset: {})
}

#Preview("Code Entry") {
    let vm = AuthViewModel()
    vm.resetEmailSent = true
    return ForgotPasswordView(viewModel: vm, onBackToLogin: {}, onPasswordReset: {})
}
