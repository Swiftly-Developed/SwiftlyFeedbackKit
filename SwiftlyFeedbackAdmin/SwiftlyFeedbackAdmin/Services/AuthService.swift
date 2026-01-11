import Foundation

actor AuthService {
    static let shared = AuthService()

    private init() {
        AppLogger.auth.info("AuthService initialized")
    }

    func signup(email: String, name: String, password: String) async throws -> AuthResponse {
        AppLogger.auth.info("📝 Starting signup for email: \(email)")
        let request = SignupRequest(email: email, name: name, password: password)
        do {
            let response: AuthResponse = try await AdminAPIClient.shared.post(
                path: "auth/signup",
                body: request,
                requiresAuth: false
            )
            AppLogger.auth.info("✅ Signup successful for user: \(response.user.id)")

            // Save token
            await MainActor.run { SecureStorageManager.shared.authToken = response.token }
            AppLogger.auth.info("🔑 Token saved to keychain")

            return response
        } catch {
            AppLogger.auth.error("❌ Signup failed: \(error.localizedDescription)")
            throw error
        }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        AppLogger.auth.info("🔐 Starting login for email: \(email)")
        let request = LoginRequest(email: email, password: password)
        do {
            let response: AuthResponse = try await AdminAPIClient.shared.post(
                path: "auth/login",
                body: request,
                requiresAuth: false
            )
            AppLogger.auth.info("✅ Login successful for user: \(response.user.id), isEmailVerified: \(response.user.isEmailVerified)")

            // Save token
            await MainActor.run { SecureStorageManager.shared.authToken = response.token }
            AppLogger.auth.info("🔑 Token saved to keychain")

            return response
        } catch {
            AppLogger.auth.error("❌ Login failed: \(error.localizedDescription)")
            throw error
        }
    }

    func logout() async throws {
        AppLogger.auth.info("🚪 Starting logout")
        do {
            try await AdminAPIClient.shared.post(path: "auth/logout", requiresAuth: true)
            AppLogger.auth.info("✅ Server logout successful")
        } catch {
            AppLogger.auth.warning("⚠️ Server logout failed (will clear token anyway): \(error.localizedDescription)")
            // Even if server logout fails, clear local token
        }
        await MainActor.run { SecureStorageManager.shared.authToken = nil }
        AppLogger.auth.info("🔑 Token deleted from keychain")
    }

    func getCurrentUser() async throws -> User {
        AppLogger.auth.info("👤 Fetching current user")
        do {
            let user: User = try await AdminAPIClient.shared.get(path: "auth/me")
            AppLogger.auth.info("✅ Got current user: \(user.id), isEmailVerified: \(user.isEmailVerified)")
            return user
        } catch {
            AppLogger.auth.error("❌ Failed to get current user: \(error.localizedDescription)")
            throw error
        }
    }

    func isLoggedIn() async -> Bool {
        let hasToken = await MainActor.run { SecureStorageManager.shared.authToken != nil }
        AppLogger.auth.debug("🔍 isLoggedIn check: \(hasToken)")
        return hasToken
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        AppLogger.auth.info("🔄 Starting password change")
        let request = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        do {
            try await AdminAPIClient.shared.put(path: "auth/password", body: request, requiresAuth: true)
            AppLogger.auth.info("✅ Password changed successfully")
            // Password changed successfully, token is invalidated - clear local token
            await MainActor.run { SecureStorageManager.shared.authToken = nil }
            AppLogger.auth.info("🔑 Token deleted from keychain after password change")
        } catch {
            AppLogger.auth.error("❌ Password change failed: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteAccount(password: String) async throws {
        AppLogger.auth.info("🗑️ Starting account deletion")
        let request = DeleteAccountRequest(password: password)
        do {
            try await AdminAPIClient.shared.delete(path: "auth/account", body: request, requiresAuth: true)
            AppLogger.auth.info("✅ Account deleted successfully")
            await MainActor.run { SecureStorageManager.shared.authToken = nil }
            AppLogger.auth.info("🔑 Token deleted from keychain after account deletion")
        } catch {
            AppLogger.auth.error("❌ Account deletion failed: \(error.localizedDescription)")
            throw error
        }
    }

    func verifyEmail(code: String) async throws -> VerifyEmailResponse {
        AppLogger.auth.info("✉️ Starting email verification with code: \(code)")
        let request = VerifyEmailRequest(code: code)
        do {
            let response: VerifyEmailResponse = try await AdminAPIClient.shared.post(
                path: "auth/verify-email",
                body: request,
                requiresAuth: false
            )
            AppLogger.auth.info("✅ Email verified successfully for user: \(response.user.id)")
            return response
        } catch {
            AppLogger.auth.error("❌ Email verification failed: \(error.localizedDescription)")
            throw error
        }
    }

    func resendVerification() async throws -> MessageResponse {
        AppLogger.auth.info("📧 Requesting verification email resend")
        do {
            let response: MessageResponse = try await AdminAPIClient.shared.post(path: "auth/resend-verification", requiresAuth: true)
            AppLogger.auth.info("✅ Verification email resent: \(response.message)")
            return response
        } catch {
            AppLogger.auth.error("❌ Resend verification failed: \(error.localizedDescription)")
            throw error
        }
    }

    func requestPasswordReset(email: String) async throws -> MessageResponse {
        AppLogger.auth.info("🔑 Requesting password reset for email: \(email)")
        let request = ForgotPasswordRequest(email: email)
        do {
            let response: MessageResponse = try await AdminAPIClient.shared.post(
                path: "auth/forgot-password",
                body: request,
                requiresAuth: false
            )
            AppLogger.auth.info("✅ Password reset requested: \(response.message)")
            return response
        } catch {
            AppLogger.auth.error("❌ Password reset request failed: \(error.localizedDescription)")
            throw error
        }
    }

    func resetPassword(code: String, newPassword: String) async throws -> MessageResponse {
        AppLogger.auth.info("🔄 Resetting password with code")
        let request = ResetPasswordRequest(code: code, newPassword: newPassword)
        do {
            let response: MessageResponse = try await AdminAPIClient.shared.post(
                path: "auth/reset-password",
                body: request,
                requiresAuth: false
            )
            AppLogger.auth.info("✅ Password reset successful: \(response.message)")
            return response
        } catch {
            AppLogger.auth.error("❌ Password reset failed: \(error.localizedDescription)")
            throw error
        }
    }
}
