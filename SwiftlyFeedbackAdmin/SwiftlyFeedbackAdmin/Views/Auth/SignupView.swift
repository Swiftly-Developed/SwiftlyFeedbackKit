import SwiftUI

struct SignupView: View {
    @Bindable var viewModel: AuthViewModel
    let onSwitchToLogin: () -> Void

    private enum SignupField: Hashable {
        case name, email, password, confirmPassword
    }

    @FocusState private var focusedField: SignupField?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Start collecting feedback today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            // Form
            VStack(spacing: 16) {
                TextField("Name", text: $viewModel.signupName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .email }
                    .submitLabel(.next)

                TextField("Email", text: $viewModel.signupEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .submitLabel(.next)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $viewModel.signupPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .onSubmit { focusedField = .confirmPassword }
                    .submitLabel(.next)

                SecureField("Confirm Password", text: $viewModel.signupConfirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .onSubmit {
                        Task { await viewModel.signup() }
                    }
                    .submitLabel(.go)

                if !viewModel.signupPassword.isEmpty {
                    PasswordStrengthView(
                        password: viewModel.signupPassword,
                        showPasswordMatch: true,
                        confirmPassword: viewModel.signupConfirmPassword
                    )
                }

                Button {
                    Task {
                        await viewModel.signup()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }

            // Switch to login
            HStack {
                Text("Already have an account?")
                    .foregroundStyle(.secondary)
                Button("Log In") {
                    onSwitchToLogin()
                }
            }
            .font(.subheadline)
        }
        .padding(32)
        .frame(maxWidth: 400)
        .onAppear {
            focusedField = .name
        }
    }
}

#Preview {
    SignupView(viewModel: AuthViewModel()) {}
}
