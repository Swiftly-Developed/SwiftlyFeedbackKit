import SwiftUI

struct AuthContainerView: View {
    @Bindable var viewModel: AuthViewModel

    private enum AuthMode {
        case login, signup, forgotPassword
    }

    @State private var authMode: AuthMode = .login

    var body: some View {
        ScrollView {
            VStack {
                Spacer(minLength: 40)

                switch authMode {
                case .login:
                    LoginView(
                        viewModel: viewModel,
                        onSwitchToSignup: {
                            withAnimation { authMode = .signup }
                        },
                        onForgotPassword: {
                            withAnimation { authMode = .forgotPassword }
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))

                case .signup:
                    SignupView(viewModel: viewModel) {
                        withAnimation { authMode = .login }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                case .forgotPassword:
                    ForgotPasswordView(
                        viewModel: viewModel,
                        onBackToLogin: {
                            withAnimation { authMode = .login }
                        },
                        onPasswordReset: {
                            withAnimation { authMode = .login }
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondary.opacity(0.1))
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

#Preview {
    AuthContainerView(viewModel: AuthViewModel())
}
