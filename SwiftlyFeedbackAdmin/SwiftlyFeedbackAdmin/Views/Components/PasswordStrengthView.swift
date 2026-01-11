import SwiftUI

/// A visual password strength indicator that shows strength level with colored bars.
///
/// Evaluates password strength based on:
/// - Length (8+ and 12+ characters)
/// - Uppercase letters
/// - Numbers
/// - Special characters
struct PasswordStrengthView: View {
    let password: String

    /// Whether to show the "Passwords match" requirement row
    var showPasswordMatch: Bool = false

    /// The confirm password to compare against (only used when showPasswordMatch is true)
    var confirmPassword: String = ""

    private var strength: (level: Int, text: String, color: Color) {
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { score += 1 }

        switch score {
        case 0...1:
            return (1, "Weak", .red)
        case 2...3:
            return (2, "Medium", .orange)
        case 4:
            return (3, "Strong", .green)
        default:
            return (4, "Very Strong", .green)
        }
    }

    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Strength bars
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < strength.level ? strength.color : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }

            // Strength text
            HStack {
                Text("Password strength:")
                    .foregroundStyle(.secondary)
                Text(strength.text)
                    .foregroundStyle(strength.color)
                    .fontWeight(.medium)
            }
            .font(.caption)

            // Optional password match indicator
            if showPasswordMatch {
                HStack(spacing: 6) {
                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(passwordsMatch ? .green : .secondary)
                        .font(.caption)
                    Text("Passwords match")
                        .font(.caption)
                        .foregroundStyle(passwordsMatch ? .primary : .secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Password strength: \(strength.text)\(showPasswordMatch ? ", Passwords \(passwordsMatch ? "match" : "do not match")" : "")")
    }
}

#Preview("Weak Password") {
    VStack(spacing: 20) {
        PasswordStrengthView(password: "abc")
        PasswordStrengthView(password: "abcdefgh")
        PasswordStrengthView(password: "Abcdefgh1")
        PasswordStrengthView(password: "Abcdefgh1!")
        PasswordStrengthView(password: "Abcdefghijkl1!")
    }
    .padding()
}

#Preview("With Password Match") {
    VStack(spacing: 20) {
        PasswordStrengthView(
            password: "Abcdefgh1!",
            showPasswordMatch: true,
            confirmPassword: "Abcdefgh1!"
        )
        PasswordStrengthView(
            password: "Abcdefgh1!",
            showPasswordMatch: true,
            confirmPassword: "different"
        )
    }
    .padding()
}
