import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - Onboarding State

    enum OnboardingStep: Int, CaseIterable {
        case welcome1 = 0
        case welcome2 = 1
        case welcome3 = 2
        case createAccount = 3
        case verifyEmail = 4
        case paywall = 5
        case projectChoice = 6
        case createProject = 7
        case joinProject = 8
        case completion = 9

        var progress: Double {
            Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
        }
    }

    enum ProjectSetupChoice {
        case create
        case join
    }

    var currentStep: OnboardingStep = .welcome1
    var projectSetupChoice: ProjectSetupChoice?

    // MARK: - Account Creation Fields

    var signupName = ""
    var signupEmail = ""
    var signupPassword = ""
    var signupConfirmPassword = ""

    // MARK: - Email Verification

    var verificationCode = ""
    var resendCooldown = 0
    private var resendTimer: Timer?

    // MARK: - Project Creation Fields

    var newProjectName = ""
    var newProjectDescription = ""

    // MARK: - Join Project Fields

    var inviteCode = ""
    var invitePreview: InvitePreview?

    // MARK: - Created Project Result

    var createdProject: Project?
    var joinedProjectName: String?

    // MARK: - Loading and Error States

    var isLoading = false
    var errorMessage: String?
    var showError = false

    // MARK: - Dependencies

    private let authViewModel: AuthViewModel
    private let projectViewModel: ProjectViewModel

    init(authViewModel: AuthViewModel, projectViewModel: ProjectViewModel) {
        self.authViewModel = authViewModel
        self.projectViewModel = projectViewModel
        AppLogger.viewModel.info("OnboardingViewModel initialized")
    }

    func invalidateTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
    }

    // MARK: - Navigation

    func goToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome1:
                currentStep = .welcome2
            case .welcome2:
                currentStep = .welcome3
            case .welcome3:
                currentStep = .createAccount
            case .createAccount:
                currentStep = .verifyEmail
            case .verifyEmail:
                currentStep = .paywall
            case .paywall:
                currentStep = .projectChoice
            case .projectChoice:
                if projectSetupChoice == .create {
                    currentStep = .createProject
                } else {
                    currentStep = .joinProject
                }
            case .createProject, .joinProject:
                currentStep = .completion
            case .completion:
                break // Handled by completing onboarding
            }
        }
        AppLogger.viewModel.info("Onboarding moved to step: \(self.currentStep)")
    }

    func goToPreviousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome1:
                break
            case .welcome2:
                currentStep = .welcome1
            case .welcome3:
                currentStep = .welcome2
            case .createAccount:
                currentStep = .welcome3
            case .verifyEmail:
                // Can't go back from email verification
                break
            case .paywall:
                // Can't go back from paywall (after verification)
                break
            case .projectChoice:
                // Can't go back to paywall
                break
            case .createProject, .joinProject:
                currentStep = .projectChoice
                projectSetupChoice = nil
            case .completion:
                // Can't go back from completion
                break
            }
        }
        AppLogger.viewModel.info("Onboarding moved back to step: \(self.currentStep)")
    }

    var canGoBack: Bool {
        switch currentStep {
        case .welcome1, .verifyEmail, .paywall, .projectChoice, .completion:
            return false
        case .welcome2, .welcome3, .createAccount, .createProject, .joinProject:
            return true
        }
    }

    // MARK: - Account Creation

    var isSignupValid: Bool {
        !signupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        signupPassword.count >= 8 &&
        signupPassword == signupConfirmPassword
    }

    func createAccount() async {
        AppLogger.viewModel.info("Onboarding: Creating account for \(self.signupEmail)")

        guard isSignupValid else {
            if signupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showError(message: "Please enter your name")
            } else if signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showError(message: "Please enter your email")
            } else if signupPassword.count < 8 {
                showError(message: "Password must be at least 8 characters")
            } else if signupPassword != signupConfirmPassword {
                showError(message: "Passwords do not match")
            }
            return
        }

        isLoading = true
        errorMessage = nil

        // Use AuthViewModel for actual signup
        authViewModel.signupName = signupName
        authViewModel.signupEmail = signupEmail
        authViewModel.signupPassword = signupPassword
        authViewModel.signupConfirmPassword = signupConfirmPassword

        await authViewModel.signup()

        if authViewModel.showError {
            showError(message: authViewModel.errorMessage ?? "Failed to create account")
            authViewModel.showError = false
        } else if authViewModel.isAuthenticated {
            AppLogger.viewModel.info("Onboarding: Account created successfully")
            goToNextStep()
        }

        isLoading = false
    }

    // MARK: - Email Verification

    var isVerificationCodeValid: Bool {
        verificationCode.count == 8
    }

    func verifyEmail() async {
        AppLogger.viewModel.info("Onboarding: Verifying email with code \(self.verificationCode)")

        guard isVerificationCodeValid else {
            showError(message: "Please enter the 8-character verification code")
            return
        }

        isLoading = true
        errorMessage = nil

        authViewModel.verificationCode = verificationCode
        await authViewModel.verifyEmail()

        if authViewModel.showError {
            showError(message: authViewModel.errorMessage ?? "Invalid verification code")
            authViewModel.showError = false
        } else if authViewModel.currentUser?.isEmailVerified == true {
            AppLogger.viewModel.info("Onboarding: Email verified successfully")
            verificationCode = ""
            goToNextStep()
        }

        isLoading = false
    }

    func resendVerificationCode() async {
        AppLogger.viewModel.info("Onboarding: Resending verification code")

        isLoading = true
        await authViewModel.resendVerification()

        if authViewModel.showError {
            showError(message: authViewModel.errorMessage ?? "Failed to resend code")
            authViewModel.showError = false
        } else {
            startResendCooldown()
        }

        isLoading = false
    }

    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    self.resendTimer?.invalidate()
                }
            }
        }
    }

    // MARK: - Project Choice

    func selectProjectChoice(_ choice: ProjectSetupChoice) {
        projectSetupChoice = choice
        goToNextStep()
    }

    // MARK: - Project Creation

    var isProjectNameValid: Bool {
        !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createProject() async {
        AppLogger.viewModel.info("Onboarding: Creating project \(self.newProjectName)")

        guard isProjectNameValid else {
            showError(message: "Please enter a project name")
            return
        }

        isLoading = true
        errorMessage = nil

        projectViewModel.newProjectName = newProjectName
        projectViewModel.newProjectDescription = newProjectDescription

        let result = await projectViewModel.createProject()
        switch result {
        case .success:
            AppLogger.viewModel.info("Onboarding: Project created successfully")
            // Load the projects to get the newly created one
            await projectViewModel.loadProjects()

            // Load the full project details to get the API key
            if let firstProject = projectViewModel.projects.first {
                await projectViewModel.loadProject(id: firstProject.id)
                createdProject = projectViewModel.selectedProject
            }

            goToNextStep()
        case .paymentRequired:
            // During onboarding, users are creating their first project which should always be free
            // This shouldn't happen, but handle it gracefully
            showError(message: "Upgrade your subscription to create more projects")
        case .otherError:
            if projectViewModel.showError {
                showError(message: projectViewModel.errorMessage ?? "Failed to create project")
                projectViewModel.showError = false
            }
        }

        isLoading = false
    }

    // MARK: - Join Project

    var isInviteCodeValid: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func previewInvite() async {
        AppLogger.viewModel.info("Onboarding: Previewing invite code \(self.inviteCode)")

        guard isInviteCodeValid else {
            showError(message: "Please enter an invite code")
            return
        }

        isLoading = true
        errorMessage = nil

        projectViewModel.inviteCode = inviteCode
        _ = await projectViewModel.previewInviteCode()

        if projectViewModel.showError {
            showError(message: projectViewModel.errorMessage ?? "Invalid invite code")
            projectViewModel.showError = false
        } else {
            invitePreview = projectViewModel.invitePreview
        }

        isLoading = false
    }

    func acceptInvite() async {
        AppLogger.viewModel.info("Onboarding: Accepting invite")

        guard invitePreview != nil else {
            showError(message: "Please verify the invite code first")
            return
        }

        isLoading = true
        errorMessage = nil

        if await projectViewModel.acceptInviteCode() {
            AppLogger.viewModel.info("Onboarding: Invite accepted successfully")
            joinedProjectName = invitePreview?.projectName
            await projectViewModel.loadProjects()
            goToNextStep()
        } else if projectViewModel.showError {
            showError(message: projectViewModel.errorMessage ?? "Failed to accept invite")
            projectViewModel.showError = false
        }

        isLoading = false
    }

    func clearInvitePreview() {
        invitePreview = nil
        projectViewModel.invitePreview = nil
    }

    // MARK: - Completion

    func completeOnboarding() {
        AppLogger.viewModel.info("Onboarding: Completing onboarding flow")
        OnboardingManager.shared.completeOnboarding()
    }

    // MARK: - Skip Project Setup (for users who want to explore first)

    func skipProjectSetup() {
        AppLogger.viewModel.info("Onboarding: Skipping project setup")
        currentStep = .completion
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        AppLogger.viewModel.error("Onboarding error: \(message)")
        errorMessage = message
        showError = true
    }

    // MARK: - Logout During Onboarding

    func logout() async {
        AppLogger.viewModel.info("Onboarding: User logging out")
        await authViewModel.logout()

        // Reset onboarding state
        currentStep = .welcome1
        signupName = ""
        signupEmail = ""
        signupPassword = ""
        signupConfirmPassword = ""
        verificationCode = ""
        newProjectName = ""
        newProjectDescription = ""
        inviteCode = ""
        invitePreview = nil
        createdProject = nil
        joinedProjectName = nil
        projectSetupChoice = nil
    }
}

// MARK: - Onboarding Manager

@MainActor
@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()

    /// Stored property that @Observable can track for SwiftUI reactivity.
    /// Synced with SecureStorageManager for persistence.
    private var _hasCompletedOnboarding: Bool

    /// Whether onboarding has been completed for the current environment.
    /// This is environment-scoped, so each environment tracks completion independently.
    var hasCompletedOnboarding: Bool {
        get {
            _hasCompletedOnboarding
        }
        set {
            _hasCompletedOnboarding = newValue
            SecureStorageManager.shared.hasCompletedOnboarding = newValue
        }
    }

    private init() {
        // Initialize stored property from SecureStorageManager
        _hasCompletedOnboarding = SecureStorageManager.shared.hasCompletedOnboarding
        AppLogger.storage.info("OnboardingManager initialized - hasCompleted: \(_hasCompletedOnboarding) for environment: \(SecureStorageManager.shared.currentEnvironment.rawValue)")
    }

    /// Marks onboarding as complete for the current environment.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        AppLogger.storage.info("Onboarding completed for environment: \(SecureStorageManager.shared.currentEnvironment.rawValue)")
    }

    /// Resets onboarding for the current environment (Developer Center feature).
    func resetOnboarding() {
        hasCompletedOnboarding = false
        AppLogger.storage.info("Onboarding reset for environment: \(SecureStorageManager.shared.currentEnvironment.rawValue)")
    }

    /// Refreshes the stored property from SecureStorageManager.
    /// Call this after environment changes to sync the state.
    func refreshFromStorage() {
        _hasCompletedOnboarding = SecureStorageManager.shared.hasCompletedOnboarding
        AppLogger.storage.info("OnboardingManager refreshed - hasCompleted: \(_hasCompletedOnboarding)")
    }
}
