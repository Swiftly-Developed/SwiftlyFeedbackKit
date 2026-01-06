import SwiftUI

struct EmailVerificationView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var resendCooldown = 0
    @State private var timer: Timer?
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Verify Your Email")
                    .font(.title)
                    .bold()

                if let email = viewModel.currentUser?.email {
                    Text("We sent a verification code to")
                        .foregroundStyle(.secondary)
                    Text(email)
                        .bold()
                }
            }

            VStack(spacing: 16) {
                TextField("Verification Code", text: $viewModel.verificationCode)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .focused($isCodeFieldFocused)
                    .onSubmit {
                        if viewModel.verificationCode.count == 8 {
                            Task { await viewModel.verifyEmail() }
                        }
                    }
                    .submitLabel(.go)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .multilineTextAlignment(.center)
                    .font(Font.title2.monospaced())

                Button {
                    Task {
                        await viewModel.verifyEmail()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Verify Email")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || viewModel.verificationCode.count != 8)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                Text("Didn't receive the code?")
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await viewModel.resendVerification()
                        startResendCooldown()
                    }
                } label: {
                    if resendCooldown > 0 {
                        Text("Resend in \(resendCooldown)s")
                    } else {
                        Text("Resend Code")
                    }
                }
                .disabled(viewModel.isLoading || resendCooldown > 0)
            }

            Spacer()

            Button("Sign Out") {
                Task {
                    await viewModel.logout()
                }
            }
            .foregroundStyle(.red)
            .padding(.bottom)
        }
        .padding()
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            isCodeFieldFocused = true
        }
        .onDisappear {
            timer?.invalidate()
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

#Preview {
    EmailVerificationView(viewModel: AuthViewModel())
}
