import Vapor

struct SignupDTO: Content, Validatable {
    let email: String
    let name: String
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("name", as: String.self, is: !.empty && .count(2...100))
        validations.add("password", as: String.self, is: .count(8...))
    }
}

struct LoginDTO: Content, Validatable {
    let email: String
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }
}

struct AuthResponseDTO: Content {
    let token: String
    let user: User.Public
}

struct TokenResponseDTO: Content {
    let token: String
}

struct ChangePasswordDTO: Content, Validatable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }

    static func validations(_ validations: inout Validations) {
        validations.add("current_password", as: String.self, is: !.empty)
        validations.add("new_password", as: String.self, is: .count(8...))
    }
}

struct DeleteAccountDTO: Content, Validatable {
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("password", as: String.self, is: !.empty)
    }
}

struct VerifyEmailDTO: Content, Validatable {
    let code: String

    static func validations(_ validations: inout Validations) {
        validations.add("code", as: String.self, is: .count(8...8))
    }
}

struct VerifyEmailResponseDTO: Content {
    let message: String
    let user: User.Public
}

struct MessageResponseDTO: Content {
    let message: String
}

struct UpdateNotificationSettingsDTO: Content {
    let notifyNewFeedback: Bool?
    let notifyNewComments: Bool?
}

struct ForgotPasswordDTO: Content, Validatable {
    let email: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

struct ResetPasswordDTO: Content, Validatable {
    let code: String
    let newPassword: String

    static func validations(_ validations: inout Validations) {
        validations.add("code", as: String.self, is: .count(8...8))
        validations.add("new_password", as: String.self, is: .count(8...))
    }
}
