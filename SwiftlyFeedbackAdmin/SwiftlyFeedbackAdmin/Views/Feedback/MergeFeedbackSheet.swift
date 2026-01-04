import SwiftUI

struct MergeFeedbackSheet: View {
    @Bindable var viewModel: FeedbackViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrimaryId: UUID?
    @State private var isMerging = false

    private var feedbacksToMerge: [Feedback] {
        viewModel.feedbacksToMerge
    }

    private var combinedStats: (votes: Int, comments: Int, mrr: Double) {
        var totalVotes = 0
        var totalComments = 0
        var totalMrr: Double = 0

        for feedback in feedbacksToMerge {
            totalVotes += feedback.voteCount
            totalComments += feedback.commentCount
            totalMrr += feedback.totalMrr ?? 0
        }

        return (totalVotes, totalComments, totalMrr)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                Divider()

                // Primary selection list
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Select the primary feedback that will keep its title and description:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        ForEach(feedbacksToMerge) { feedback in
                            primarySelectionRow(feedback: feedback)
                        }
                    }
                    .padding(.vertical)
                }

                Divider()

                // Preview section
                previewSection

                Divider()

                // Warning and actions
                footerSection
            }
            .navigationTitle("Merge Feedback")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Default to the feedback with most votes
                if selectedPrimaryId == nil {
                    selectedPrimaryId = feedbacksToMerge.max(by: { $0.voteCount < $1.voteCount })?.id
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.merge")
                .font(.largeTitle)
                .foregroundStyle(.indigo)
            Text("Merge \(feedbacksToMerge.count) Feedback Items")
                .font(.headline)
        }
        .padding()
    }

    // MARK: - Primary Selection Row

    private func primarySelectionRow(feedback: Feedback) -> some View {
        Button {
            selectedPrimaryId = feedback.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedPrimaryId == feedback.id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedPrimaryId == feedback.id ? .blue : .secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        FeedbackStatusBadge(status: feedback.status)
                        FeedbackCategoryBadge(category: feedback.category)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                            Text("\(feedback.voteCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                    }

                    Text(feedback.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(feedback.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if feedback.commentCount > 0 {
                        Label("\(feedback.commentCount) comments", systemImage: "bubble.left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            #if os(macOS)
            .background(selectedPrimaryId == feedback.id ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            #else
            .background(selectedPrimaryId == feedback.id ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPrimaryId == feedback.id ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After merge:")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                statItem(icon: "arrow.up", value: "\(combinedStats.votes)", label: "votes")
                statItem(icon: "bubble.left", value: "\(combinedStats.comments)", label: "comments")
                statItem(icon: "dollarsign.circle", value: formatMrr(combinedStats.mrr), label: "MRR")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemGroupedBackground))
        #endif
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatMrr(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Secondary items will be archived. This action cannot be undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task {
                    await performMerge()
                }
            } label: {
                if isMerging {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Merging...")
                    }
                } else {
                    Text("Merge \(feedbacksToMerge.count) Items")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPrimaryId == nil || isMerging)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    // MARK: - Actions

    private func performMerge() async {
        guard let primaryId = selectedPrimaryId else { return }

        isMerging = true
        let success = await viewModel.mergeFeedback(primaryId: primaryId)
        isMerging = false

        if success {
            dismiss()
        }
    }
}

#Preview {
    MergeFeedbackSheet(viewModel: FeedbackViewModel())
}
