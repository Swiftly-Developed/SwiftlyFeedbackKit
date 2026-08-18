import SwiftUI

public struct FeedbackDetailView: View {
    let feedback: Feedback
    let swiftlyFeedback: SwiftlyFeedback?
    @State private var viewModel: FeedbackDetailViewModel
    @State private var translator = FeedbackTranslator()
    @SwiftUI.Environment(\.locale) private var locale

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    public init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback? = nil) {
        self.feedback = feedback
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        _viewModel = State(wrappedValue: FeedbackDetailViewModel(
            feedback: feedback,
            swiftlyFeedback: swiftlyFeedback ?? SwiftlyFeedback.shared
        ))
    }

    public var body: some View {
        Group {
            if viewModel.hasInvalidApiKey {
                InvalidApiKeyView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        FeedbackDetailHeaderView(
                            feedback: feedback,
                            translatedTitle: headerProjection.title,
                            translatedDescription: headerProjection.description,
                            translatedRejectionReason: headerProjection.rejectionReason,
                            translationSourceName: headerProjection.sourceName,
                            isShowingOriginal: isShowingOriginalHeader,
                            onToggleTranslation: {
                                viewModel.toggleShowOriginal(viewModel.currentFeedback.id)
                            }
                        )
                        FeedbackDetailVoteView(viewModel: viewModel)

                        if config.showCommentSection {
                            FeedbackDetailCommentsView(viewModel: viewModel, translator: translator)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    if config.showCommentSection {
                        await viewModel.loadComments()
                    }
                }
            }
        }
        .navigationTitle(displayedTitle)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                ShareLink(item: "\(viewModel.currentFeedback.title)\n\n\(viewModel.currentFeedback.description)") {
                    Label(String(localized: .toolbarShare), systemImage: "square.and.arrow.up")
                }
            }
            #if os(macOS)
            if config.showCommentSection {
                ToolbarItem {
                    Button(String(localized: .toolbarRefresh), systemImage: "arrow.clockwise") {
                        Task { await viewModel.loadComments() }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help(String(localized: .toolbarRefresh))
                }
            }
            #endif
        }
        .task {
            if config.showCommentSection {
                await viewModel.loadComments()
            }
        }
        .feedbackTranslationTask(translator)
        .onChange(of: viewModel.currentFeedback, initial: true) {
            enqueueTranslations()
        }
        .onChange(of: viewModel.comments) {
            enqueueTranslations()
        }
        .onChange(of: locale) {
            // A locale change invalidates every cached projection (the target
            // moved), then re-detects and re-enqueues against the new target.
            translator.invalidateAll()
            enqueueTranslations()
        }
        .onAppear {
            if SwiftlyFeedback.config.enableAutomaticViewTracking {
                SwiftlyFeedback.view(.feedbackDetail, properties: ["feedbackId": feedback.id.uuidString])
            }
        }
        .alert(String(localized: .errorTitle), isPresented: $viewModel.showingError) {
            Button(String(localized: .errorOk), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? String(localized: .errorGeneric))
        }
        .sheet(isPresented: $viewModel.showingVoteDialog) {
            VoteDialogView(
                email: $viewModel.voteEmail,
                notifyStatusChange: $viewModel.voteNotifyStatusChange,
                subscribeToMailingList: $viewModel.voteSubscribeToMailingList,
                operationalEmails: $viewModel.voteOperationalEmails,
                marketingEmails: $viewModel.voteMarketingEmails
            ) { email, notify, subscribeToMailingList, mailingListEmailTypes in
                Task {
                    await viewModel.submitVote(
                        email: email,
                        notify: notify,
                        subscribeToMailingList: subscribeToMailingList,
                        mailingListEmailTypes: mailingListEmailTypes
                    )
                }
            }
        }
    }

    /// Whether the header (title + description + rejection reason together — one
    /// toggle governs all three) is showing its original-language text.
    private var isShowingOriginalHeader: Bool {
        viewModel.showOriginalIDs.contains(viewModel.currentFeedback.id)
    }

    /// The header's translation inputs: cached projections plus the localized
    /// source-language name. All `nil` (affordance absent, original text stands)
    /// until the cache fills, and when the source language has no localized display
    /// name — a raw code is never shown.
    private var headerProjection: (
        title: String?, description: String?, rejectionReason: String?, sourceName: String?
    ) {
        let item = viewModel.currentFeedback
        let target = locale.language
        let title = translator.translation(
            for: item.id, field: .title, target: target, sourceText: item.title
        )
        let description = translator.translation(
            for: item.id, field: .description, target: target, sourceText: item.description
        )
        let rejectionReason = item.rejectionReason.flatMap {
            translator.translation(for: item.id, field: .rejectionReason, target: target, sourceText: $0)
        }
        guard title != nil || description != nil || rejectionReason != nil else {
            return (nil, nil, nil, nil)
        }
        let source = SourceLanguageDetector.detect(item.description)
            ?? SourceLanguageDetector.detect(item.title)
        guard let sourceName = source?.localizedDisplayName(in: locale) else {
            return (nil, nil, nil, nil)
        }
        return (title, description, rejectionReason, sourceName)
    }

    /// The navigation title uses the same projection as the header's title text.
    private var displayedTitle: String {
        if !isShowingOriginalHeader, headerProjection.sourceName != nil,
           let translated = headerProjection.title {
            return translated
        }
        return viewModel.currentFeedback.title
    }

    /// Detects source languages per field for the feedback and its comments and
    /// queues the uncached remainder toward the current locale. Skipped entirely
    /// when the target locale carries no language code.
    private func enqueueTranslations() {
        let target = locale.language
        guard target.languageCode != nil else { return }
        var units = SourceLanguageDetector.units(for: viewModel.currentFeedback, target: target)
        units += viewModel.comments.compactMap {
            SourceLanguageDetector.unit(for: $0, target: target)
        }
        translator.enqueue(units: units, target: target)
    }
}

struct FeedbackDetailHeaderView: View {
    let feedback: Feedback
    /// Translated projections, `nil` when no translation is cached (defaults keep
    /// existing call sites source-compatible). One affordance below the description
    /// governs title, description, and rejection reason together.
    var translatedTitle: String? = nil
    var translatedDescription: String? = nil
    var translatedRejectionReason: String? = nil
    /// Localized source-language name; `nil` means the affordance is absent.
    var translationSourceName: String? = nil
    var isShowingOriginal: Bool = false
    var onToggleTranslation: (() -> Void)? = nil

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    private var displayedTitle: String {
        if !isShowingOriginal, let translatedTitle { return translatedTitle }
        return feedback.title
    }

    private var displayedDescription: String {
        if !isShowingOriginal, let translatedDescription { return translatedDescription }
        return feedback.description
    }

    private func displayedRejectionReason(_ reason: String) -> String {
        if !isShowingOriginal, let translatedRejectionReason { return translatedRejectionReason }
        return reason
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if config.showStatusBadge {
                    StatusBadge(status: feedback.status)
                }
                if config.showCategoryBadge {
                    CategoryBadge(category: feedback.category)
                }
                Spacer()
            }

            Text(displayedTitle)
                .font(.title2)
                .bold()

            Text(displayedDescription)
                .font(.body)
                .foregroundStyle(.secondary)

            if let translationSourceName, let onToggleTranslation {
                TranslationAffordanceView(
                    sourceLanguageName: translationSourceName,
                    isShowingOriginal: isShowingOriginal,
                    onToggle: onToggleTranslation
                )
            }

            // Rejection reason section (only shown when status is rejected and reason is provided)
            if feedback.status == .rejected,
               let reason = feedback.rejectionReason,
               !reason.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text(String(localized: .rejectionReasonTitle))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.red)

                    Text(displayedRejectionReason(reason))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: .accessibilityRejectionReason(displayedRejectionReason(reason))))
            }

            if let createdAt = feedback.createdAt {
                Text(String(localized: .feedbackDetailSubmitted(createdAt.formatted(date: .abbreviated, time: .shortened))))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct FeedbackDetailVoteView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var themeColor: Color {
        theme.primaryColor.resolve(for: colorScheme)
    }

    private var isDisabled: Bool {
        let status = viewModel.currentFeedback.status
        let hasVoted = viewModel.currentFeedback.hasVoted
        return !status.canVote || (!config.allowUndoVote && hasVoted)
    }

    private var foregroundColor: Color {
        if !viewModel.currentFeedback.status.canVote {
            return .secondary.opacity(0.5)
        }
        return themeColor
    }

    private var backgroundColor: Color {
        if viewModel.currentFeedback.hasVoted {
            return themeColor.opacity(0.15)
        }
        return .clear
    }

    private var borderColor: Color {
        if !viewModel.currentFeedback.status.canVote {
            return .secondary.opacity(0.3)
        }
        return themeColor.opacity(0.5)
    }

    var body: some View {
        Button {
            Task { await viewModel.toggleVote() }
        } label: {
            HStack(spacing: 12) {
                if config.showVoteCount {
                    VStack(spacing: 2) {
                        Image(systemName: viewModel.currentFeedback.hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                            .font(.system(size: 14, weight: .bold))
                        Text(viewModel.currentFeedback.voteCount, format: .number)
                            .font(.system(size: 13))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(foregroundColor)
                    .frame(width: 44, height: 44)
                }

                Text(viewModel.currentFeedback.hasVoted
                     ? String(localized: .buttonVoted)
                     : String(localized: .buttonVote))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(foregroundColor)

                Spacer()
            }
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(String(localized: .accessibilityVoteCount(viewModel.currentFeedback.voteCount)))
        .accessibilityValue(viewModel.currentFeedback.hasVoted ? String(localized: .accessibilityVoted) : String(localized: .accessibilityNotVoted))
        .accessibilityHint(
            !viewModel.currentFeedback.status.canVote
                ? String(localized: .accessibilityVotingClosed)
                : viewModel.currentFeedback.hasVoted
                    ? String(localized: .accessibilityUnvoteHint)
                    : String(localized: .accessibilityVoteHint)
        )
    }
}

struct FeedbackDetailCommentsView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    let translator: FeedbackTranslator
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.locale) private var locale

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    /// A comment row's translation inputs: the cached projection plus the localized
    /// source-language name. Both `nil` (affordance absent, original text stands)
    /// until the cache fills, and when the source language has no localized display
    /// name — a raw code is never shown.
    private func translationProjection(for comment: Comment) -> (text: String?, sourceName: String?) {
        let target = locale.language
        guard let text = translator.translation(
            for: comment.id, field: .commentText, target: target, sourceText: comment.content
        ) else {
            return (nil, nil)
        }
        guard let sourceName = SourceLanguageDetector.detect(comment.content)?
            .localizedDisplayName(in: locale) else {
            return (nil, nil)
        }
        return (text, sourceName)
    }

    /// Placeholder comment for the loading skeleton: plausible metrics (a
    /// one-line author row and a body long enough to wrap), never rendered
    /// legibly — always redacted. Same pattern as `FeedbackCardSkeletonView`.
    private static let placeholder = Comment(
        id: UUID(),
        content: "Placeholder comment body that is long enough to wrap onto a second line at typical widths.",
        userId: "placeholder",
        isAdmin: false,
        createdAt: nil
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .commentsCount(viewModel.comments.count)))
                .font(.headline)

            if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                // Ghost rows: the real `CommentRowView` fed placeholder values,
                // so the transition to loaded content shifts nothing.
                ForEach(0..<3, id: \.self) { _ in
                    CommentRowView(comment: Self.placeholder)
                }
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: .accessibilityLoadingComments))
            } else if viewModel.comments.isEmpty && viewModel.hasLoadedCommentsOnce {
                // Gated on a fetch-completed fact, never `isEmpty` alone — a
                // failed first load renders neither ghosts nor a false
                // "no comments" claim (the error alert has already fired).
                CommentsEmptyStateView()
            } else if !viewModel.comments.isEmpty {
                ForEach(viewModel.comments) { comment in
                    let projection = translationProjection(for: comment)
                    CommentRowView(
                        comment: comment,
                        translatedText: projection.text,
                        translationSourceName: projection.sourceName,
                        isShowingOriginal: viewModel.showOriginalIDs.contains(comment.id),
                        onToggleTranslation: { viewModel.toggleShowOriginal(comment.id) }
                    )
                }
            }

            HStack {
                TextField(String(localized: .feedbackDetailCommentsAdd), text: $viewModel.newCommentText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: .accessibilityAddComment))

                Button {
                    Task { await viewModel.submitComment() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .tint(theme.primaryColor.resolve(for: colorScheme))
                .disabled(viewModel.newCommentText.isEmpty || viewModel.isSubmittingComment)
                .accessibilityLabel(String(localized: .accessibilityPostComment))
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct CommentRowView: View {
    let comment: Comment
    /// Translated projection, `nil` when no translation is cached (defaults keep
    /// existing call sites — including the skeleton placeholder — source-compatible).
    var translatedText: String? = nil
    /// Localized source-language name; `nil` means the affordance is absent.
    var translationSourceName: String? = nil
    var isShowingOriginal: Bool = false
    var onToggleTranslation: (() -> Void)? = nil

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var displayedContent: String {
        if !isShowingOriginal, let translatedText { return translatedText }
        return comment.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.isAdmin ? String(localized: .commentAuthorTeam) : String(localized: .commentAuthorUser))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(comment.isAdmin ? theme.primaryColor.resolve(for: colorScheme) : .secondary)

                if let createdAt = comment.createdAt {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(displayedContent)
                .font(.subheadline)

            if let translationSourceName, let onToggleTranslation {
                TranslationAffordanceView(
                    sourceLanguageName: translationSourceName,
                    isShowingOriginal: isShowingOriginal,
                    onToggle: onToggleTranslation
                )
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
@Observable
final class FeedbackDetailViewModel {
    var currentFeedback: Feedback
    var comments: [Comment] = []
    var isLoadingComments = false
    /// True once a comments fetch has completed successfully — the empty state
    /// is gated on this, never on `comments.isEmpty` alone.
    var hasLoadedCommentsOnce = false
    var newCommentText = ""
    var isSubmittingComment = false
    var showingError = false
    var errorMessage: String?
    var hasInvalidApiKey = false
    /// Items (the feedback id governs title + description + rejection reason
    /// together; each comment id its own row) toggled back to original-language
    /// text. Session-scoped: lives exactly as long as this view model, never persisted.
    var showOriginalIDs: Set<UUID> = []

    // Vote dialog state
    var showingVoteDialog = false
    var voteEmail = ""
    var voteNotifyStatusChange = false
    var voteSubscribeToMailingList = SwiftlyFeedback.config.mailingListDefaultOptIn
    var voteOperationalEmails = true
    var voteMarketingEmails = true

    private let swiftlyFeedback: SwiftlyFeedback?

    init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback?) {
        self.currentFeedback = feedback
        self.swiftlyFeedback = swiftlyFeedback
        self.voteNotifyStatusChange = SwiftlyFeedback.config.voteNotificationDefaultOptIn
    }

    /// Flips one item (the feedback header as a whole, or one comment) between its
    /// translation and its original text.
    func toggleShowOriginal(_ id: UUID) {
        if showOriginalIDs.contains(id) {
            showOriginalIDs.remove(id)
        } else {
            showOriginalIDs.insert(id)
        }
    }

    func loadComments() async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        isLoadingComments = true
        defer { isLoadingComments = false }

        do {
            comments = try await sf.getComments(for: currentFeedback.id)
            hasLoadedCommentsOnce = true
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

    func toggleVote() async {
        guard swiftlyFeedback != nil else { return }
        guard !hasInvalidApiKey else { return }

        let config = SwiftlyFeedback.config

        if currentFeedback.hasVoted {
            // Unvoting - no dialog needed
            if !config.allowUndoVote { return }
            await submitVote(email: nil, notify: false)
        } else {
            // Check if userEmail is already configured
            let configuredEmail = config.userEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasConfiguredEmail = configuredEmail?.isEmpty == false

            if hasConfiguredEmail {
                // Use configured email directly, no dialog needed
                await submitVote(email: configuredEmail, notify: config.voteNotificationDefaultOptIn, subscribeToMailingList: config.mailingListDefaultOptIn, mailingListEmailTypes: buildVoteEmailTypes())
            } else if config.showVoteEmailField {
                // No configured email - show dialog to collect email
                voteEmail = ""
                voteNotifyStatusChange = config.voteNotificationDefaultOptIn
                voteSubscribeToMailingList = config.mailingListDefaultOptIn
                showingVoteDialog = true
            } else {
                // No email configured and dialog disabled - vote without email
                await submitVote(email: nil, notify: false)
            }
        }
    }

    func buildVoteEmailTypes() -> [String]? {
        guard voteSubscribeToMailingList else { return nil }
        var types: [String] = []
        if voteOperationalEmails { types.append("operational") }
        if voteMarketingEmails { types.append("marketing") }
        return types.isEmpty ? nil : types
    }

    func submitVote(email: String?, notify: Bool, subscribeToMailingList: Bool? = nil, mailingListEmailTypes: [String]? = nil) async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        do {
            let result: VoteResult
            if currentFeedback.hasVoted {
                result = try await sf.unvote(for: currentFeedback.id)
            } else {
                let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
                let validEmail = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil
                result = try await sf.vote(
                    for: currentFeedback.id,
                    email: validEmail,
                    notifyStatusChange: notify && validEmail != nil,
                    subscribeToMailingList: validEmail != nil ? subscribeToMailingList : nil,
                    mailingListEmailTypes: validEmail != nil && subscribeToMailingList == true ? mailingListEmailTypes : nil
                )
            }

            currentFeedback = Feedback(
                id: currentFeedback.id,
                title: currentFeedback.title,
                description: currentFeedback.description,
                status: currentFeedback.status,
                category: currentFeedback.category,
                userId: currentFeedback.userId,
                userEmail: currentFeedback.userEmail,
                voteCount: result.voteCount,
                hasVoted: result.hasVoted,
                commentCount: currentFeedback.commentCount,
                createdAt: currentFeedback.createdAt,
                updatedAt: currentFeedback.updatedAt,
                mergedIntoId: currentFeedback.mergedIntoId,
                mergedAt: currentFeedback.mergedAt,
                mergedFeedbackIds: currentFeedback.mergedFeedbackIds,
                rejectionReason: currentFeedback.rejectionReason
            )
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

    func submitComment() async {
        guard let sf = swiftlyFeedback, !newCommentText.isEmpty else { return }
        guard !hasInvalidApiKey else { return }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let comment = try await sf.addComment(to: currentFeedback.id, content: newCommentText)
            comments.append(comment)
            newCommentText = ""
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
