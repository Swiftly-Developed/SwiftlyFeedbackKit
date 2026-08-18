import SwiftUI

public struct SubmitFeedbackView: View {
    let swiftlyFeedback: SwiftlyFeedback?
    let onDismiss: () -> Void

    @State private var viewModel = SubmitFeedbackViewModel()
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private enum Field: Hashable {
        case title, description, email
    }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil, onDismiss: @escaping () -> Void = {}) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasInvalidApiKey {
                    InvalidApiKeyView()
                } else {
                    formContent
                }
            }
            .navigationTitle(String(localized: .feedbackSubmitTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: .buttonCancel)) {
                        dismiss()
                        onDismiss()
                    }
                }
                if !viewModel.hasInvalidApiKey {
                    ToolbarItem(placement: .confirmationAction) {
                        submitButton
                    }
                }
            }
            .alert(String(localized: .errorTitle), isPresented: $viewModel.showingError) {
                Button(String(localized: .errorOk), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? String(localized: .errorGeneric))
            }
            .overlay {
                if viewModel.isSubmitting {
                    // S1: action progress (submit in flight), not a content load — the spinner is the mandated treatment.
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 12))
                        .accessibilityLabel(String(localized: .accessibilitySubmitting))
                }
            }
            .onAppear {
                if SwiftlyFeedback.config.enableAutomaticViewTracking {
                    SwiftlyFeedback.view(.submitFeedback)
                }
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        #if os(macOS)
        macOSForm
        #else
        iOSForm
        #endif
    }

    // MARK: - iOS/iPadOS Form

    #if !os(macOS)
    private var iOSForm: some View {
        Form {
            Section {
                TextField(String(localized: .feedbackFormTitle), text: $viewModel.title)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .description }
                    .accessibilityHint(String(localized: .accessibilityFormRequired))

                Picker(String(localized: .feedbackFormCategory), selection: $viewModel.category) {
                    ForEach(FeedbackCategory.allCases, id: \.self) { category in
                        Label(category.localizedDisplayName, systemImage: category.iconName)
                            .tag(category)
                    }
                }
            }
            .disabled(viewModel.isSubmitting)

            Section {
                TextEditor(text: $viewModel.description)
                    .focused($focusedField, equals: .description)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: .feedbackFormDescription))
                    .accessibilityHint(String(localized: .accessibilityFormDescriptionHint))
            } header: {
                Text(String(localized: .feedbackFormDescription))
            } footer: {
                if let unmetRequirement = viewModel.unmetRequirement {
                    Text(unmetRequirement)
                        .font(.caption)
                }
            }
            .disabled(viewModel.isSubmitting)

            if config.showEmailField {
                Section {
                    TextField(String(localized: .feedbackFormEmailPlaceholder), text: $viewModel.email)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { submitIfValid() }
                        .accessibilityHint(String(localized: .accessibilityFormOptional))

                    if config.showMailingListOptIn && !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Toggle(String(localized: .mailingListOptIn), isOn: $viewModel.subscribeToMailingList)

                        if viewModel.subscribeToMailingList {
                            Toggle(String(localized: .mailingListOperational), isOn: $viewModel.operationalEmails)
                                .padding(.leading, 20)
                            Toggle(String(localized: .mailingListMarketing), isOn: $viewModel.marketingEmails)
                                .padding(.leading, 20)
                        }
                    }
                } header: {
                    Text(String(localized: .feedbackFormEmail))
                } footer: {
                    Text(String(localized: .feedbackFormEmailFooter))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        // `scrollDismissesKeyboard` is iOS-family-only and unavailable on
        // visionOS, which also compiles this `#if !os(macOS)` block.
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }
    #endif

    // MARK: - macOS Form

    #if os(macOS)
    private var macOSForm: some View {
        VStack(spacing: 0) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    Text("\(String(localized: .feedbackFormTitle)):")
                        .gridColumnAlignment(.trailing)
                    TextField(String(localized: .feedbackFormTitlePlaceholder), text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { focusedField = .description }
                        .accessibilityLabel(String(localized: .feedbackFormTitle))
                        .accessibilityHint(String(localized: .accessibilityFormRequired))
                }

                GridRow {
                    Text("\(String(localized: .feedbackFormCategory)):")
                    Picker("", selection: $viewModel.category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.localizedDisplayName).tag(category)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                GridRow(alignment: .top) {
                    Text("\(String(localized: .feedbackFormDescription)):")
                    TextEditor(text: $viewModel.description)
                        .focused($focusedField, equals: .description)
                        .font(.body)
                        .frame(minHeight: 120, maxHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                        .accessibilityLabel(String(localized: .feedbackFormDescription))
                        .accessibilityHint(String(localized: .accessibilityFormDescriptionHint))
                }

                if config.showEmailField {
                    GridRow {
                        Text("\(String(localized: .feedbackFormEmail)):")
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(String(localized: .feedbackFormEmailPlaceholder), text: $viewModel.email)
                                .focused($focusedField, equals: .email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .onSubmit { submitIfValid() }
                                .accessibilityLabel(String(localized: .feedbackFormEmail))
                                .accessibilityHint(String(localized: .accessibilityFormOptional))
                            Text(String(localized: .feedbackFormEmailFooter))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if config.showMailingListOptIn && !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        GridRow {
                            Text("")
                            Toggle(String(localized: .mailingListOptIn), isOn: $viewModel.subscribeToMailingList)
                        }

                        if viewModel.subscribeToMailingList {
                            GridRow {
                                Text("")
                                Toggle(String(localized: .mailingListOperational), isOn: $viewModel.operationalEmails)
                                    .padding(.leading, 20)
                            }
                            GridRow {
                                Text("")
                                Toggle(String(localized: .mailingListMarketing), isOn: $viewModel.marketingEmails)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .disabled(viewModel.isSubmitting)

            if let unmetRequirement = viewModel.unmetRequirement {
                Text(unmetRequirement)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
    }
    #endif

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            submitIfValid()
        } label: {
            #if os(macOS)
            Text(String(localized: .buttonSubmit))
            #else
            if viewModel.isSubmitting {
                // S1: action progress (submit in flight), not a content load — the spinner is the mandated treatment.
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(String(localized: .buttonSubmit))
            }
            #endif
        }
        .tint(theme.primaryColor.resolve(for: colorScheme))
        .disabled(!viewModel.isValid || viewModel.isSubmitting)
        .accessibilityHint(viewModel.isValid ? String(localized: .accessibilitySubmitHint) : (viewModel.unmetRequirement ?? String(localized: .accessibilitySubmitDisabledHint)))
        #if os(macOS)
        .keyboardShortcut(.return, modifiers: .command)
        #endif
    }

    // MARK: - Actions

    private func submitIfValid() {
        guard viewModel.isValid, !viewModel.isSubmitting else { return }
        Task {
            await viewModel.submit(using: swiftlyFeedback)
            if viewModel.isSubmitted {
                dismiss()
                onDismiss()
            }
        }
    }
}

@MainActor
@Observable
final class SubmitFeedbackViewModel {
    var title = ""
    var description = ""
    var category: FeedbackCategory = .featureRequest
    var email = SwiftlyFeedback.config.userEmail ?? ""
    var subscribeToMailingList = SwiftlyFeedback.config.mailingListDefaultOptIn
    var operationalEmails = true
    var marketingEmails = true
    var isSubmitting = false
    var isSubmitted = false
    var showingError = false
    var errorMessage: String?
    var hasInvalidApiKey = false

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The reason the form cannot be submitted yet, title-first (same trimming
    /// as `isValid`), or `nil` when the form is valid. Rendered visually under
    /// the form and read by VoiceOver on the submit button's hint.
    var unmetRequirement: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: .feedbackFormValidationTitleRequired)
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: .feedbackFormValidationDescriptionRequired)
        }
        return nil
    }

    func buildEmailTypes() -> [String]? {
        guard subscribeToMailingList else { return nil }
        var types: [String] = []
        if operationalEmails { types.append("operational") }
        if marketingEmails { types.append("marketing") }
        return types.isEmpty ? nil : types
    }

    func submit(using swiftlyFeedback: SwiftlyFeedback?) async {
        guard let sf = swiftlyFeedback, isValid else { return }
        guard !hasInvalidApiKey else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await sf.submitFeedback(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                email: email.isEmpty ? nil : email,
                subscribeToMailingList: !email.isEmpty ? subscribeToMailingList : nil,
                mailingListEmailTypes: !email.isEmpty ? buildEmailTypes() : nil
            )
            isSubmitted = true
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: .errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
