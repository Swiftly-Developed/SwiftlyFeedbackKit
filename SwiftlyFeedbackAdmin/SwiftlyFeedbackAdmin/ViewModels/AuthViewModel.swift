import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.swiftlyfeedback.admin", category: "AuthViewModel")

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    var showError = false

    // Login fields
    var loginEmail = ""
    var loginPassword = ""

    // Signup fields
    var signupEmail = ""
    var signupName = ""
    var signupPassword = ""
    var signupConfirmPassword = ""

    // Email verification
    var verificationCode = ""

    var needsEmailVerification: Bool {
        let needs = isAuthenticated && currentUser?.isEmailVerified == false
        logger.debug("🔍 needsEmailVerification: \(needs) (isAuthenticated: \(self.isAuthenticated), isEmailVerified: \(self.currentUser?.isEmailVerified ?? false))")
        return needs
    }

    init() {
        logger.info("AuthViewModel initialized")
        // Check if user is already logged in
        checkAuthState()
    }

    func checkAuthState() {
        logger.info("🔄 Checking auth state...")
        Task {
            if KeychainService.getToken() != nil {
                logger.info("🔑 Token found in keychain, fetching current user...")
                do {
                    currentUser = try await AuthService.shared.getCurrentUser()
                    isAuthenticated = true
                    logger.info("✅ Auth state restored - user: \(self.currentUser?.id.uuidString ?? "nil"), isEmailVerified: \(self.currentUser?.isEmailVerified ?? false)")
                } catch {
                    logger.error("❌ Failed to restore auth state: \(error.localizedDescription)")
                    // Token invalid or expired
                    KeychainService.deleteToken()
                    isAuthenticated = false
                    logger.info("🔑 Invalid token deleted from keychain")
                }
            } else {
                logger.info("🔑 No token in keychain - user not authenticated")
            }
        }
    }

    func login() async {
        logger.info("🔐 Login attempt for: \(self.loginEmail)")
        guard !loginEmail.isEmpty, !loginPassword.isEmpty else {
            logger.warning("⚠️ Login validation failed - empty fields")
            showError(message: "Please enter email and password")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.login(
                email: loginEmail,
                password: loginPassword
            )
            currentUser = response.user
            isAuthenticated = true
            logger.info("✅ Login successful - isEmailVerified: \(response.user.isEmailVerified)")
            clearLoginFields()
        } catch {
            logger.error("❌ Login failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func signup() async {
        logger.info("📝 Signup attempt for: \(self.signupEmail)")
        guard !signupEmail.isEmpty, !signupName.isEmpty, !signupPassword.isEmpty else {
            logger.warning("⚠️ Signup validation failed - empty fields")
            showError(message: "Please fill in all fields")
            return
        }

        guard signupPassword == signupConfirmPassword else {
            logger.warning("⚠️ Signup validation failed - passwords don't match")
            showError(message: "Passwords do not match")
            return
        }

        guard signupPassword.count >= 8 else {
            logger.warning("⚠️ Signup validation failed - password too short")
            showError(message: "Password must be at least 8 characters")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.signup(
                email: signupEmail,
                name: signupName,
                password: signupPassword
            )
            currentUser = response.user
            isAuthenticated = true
            logger.info("✅ Signup successful - isEmailVerified: \(response.user.isEmailVerified)")
            clearSignupFields()
        } catch {
            logger.error("❌ Signup failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func logout() async {
        logger.info("🚪 Logout initiated")
        isLoading = true

        do {
            try await AuthService.shared.logout()
            logger.info("✅ Logout successful")
        } catch {
            logger.warning("⚠️ Logout error (ignoring): \(error.localizedDescription)")
            // Ignore logout errors
        }

        currentUser = nil
        isAuthenticated = false
        isLoading = false
        logger.info("🔄 Auth state cleared")
    }

    private func showError(message: String) {
        logger.error("⚠️ Showing error to user: \(message)")
        errorMessage = message
        showError = true
    }

    private func clearLoginFields() {
        loginEmail = ""
        loginPassword = ""
    }

    private func clearSignupFields() {
        signupEmail = ""
        signupName = ""
        signupPassword = ""
        signupConfirmPassword = ""
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        logger.info("🔄 Password change initiated")
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            logger.info("✅ Password changed successfully")
            // Password changed successfully - don't change auth state here
            // Let the caller dismiss sheets first, then call forceLogout()
            isLoading = false
            return true
        } catch {
            logger.error("❌ Password change failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func forceLogout() {
        logger.info("🚪 Force logout")
        currentUser = nil
        isAuthenticated = false
    }

    func deleteAccount(password: String) async -> Bool {
        logger.info("🗑️ Account deletion initiated")
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService.shared.deleteAccount(password: password)
            logger.info("✅ Account deleted successfully")
            // Account deleted successfully - don't change auth state here
            // Let the caller dismiss sheets first, then call forceLogout()
            isLoading = false
            return true
        } catch {
            logger.error("❌ Account deletion failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func verifyEmail() async {
        logger.info("✉️ Email verification initiated with code: \(self.verificationCode)")
        guard verificationCode.count == 8 else {
            logger.warning("⚠️ Invalid verification code length: \(self.verificationCode.count)")
            showError(message: "Please enter the 8-character verification code")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.verifyEmail(code: verificationCode)
            logger.info("✅ Email verified - updating currentUser")
            logger.info("📊 Before update: currentUser.isEmailVerified = \(self.currentUser?.isEmailVerified ?? false)")
            currentUser = response.user
            logger.info("📊 After update: currentUser.isEmailVerified = \(self.currentUser?.isEmailVerified ?? false)")
            verificationCode = ""
        } catch {
            logger.error("❌ Email verification failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
        logger.info("📊 Final state: isAuthenticated=\(self.isAuthenticated), needsEmailVerification=\(self.needsEmailVerification)")
    }

    func resendVerification() async {
        logger.info("📧 Resend verification initiated")
        isLoading = true
        errorMessage = nil

        do {
            _ = try await AuthService.shared.resendVerification()
            logger.info("✅ Verification email resent")
        } catch {
            logger.error("❌ Resend verification failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func updateNotificationSettings(notifyNewFeedback: Bool?, notifyNewComments: Bool?) async {
        logger.info("🔔 Updating notification settings - feedback: \(String(describing: notifyNewFeedback)), comments: \(String(describing: notifyNewComments))")

        do {
            let updatedUser = try await AdminAPIClient.shared.updateNotificationSettings(
                notifyNewFeedback: notifyNewFeedback,
                notifyNewComments: notifyNewComments
            )
            currentUser = updatedUser
            logger.info("✅ Notification settings updated")
        } catch {
            logger.error("❌ Failed to update notification settings: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }
    }
}
