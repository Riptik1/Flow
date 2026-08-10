import SwiftUI

struct SuggestImprovementsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var feedback: String = ""
    @State private var showSent = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Suggest Improvements")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    Text("We'd love to hear your ideas. What can we do better?")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    GlassCard(cornerRadius: 16, padding: 16) {
                        TextEditor(text: $feedback)
                            .font(.system(size: 16))
                            .frame(minHeight: 120)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)
                }
            }

            Button {
                sendFeedback()
            } label: {
                Text("Send Feedback")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(feedback.isEmpty ? Color.secondary.opacity(0.3) : Color.blue)
                    )
            }
            .disabled(feedback.isEmpty)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay {
            if showSent {
                sentOverlay
            }
        }
    }

    private var sentOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            GlassCard(cornerRadius: 20, padding: 24) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    Text("Thank You!")
                        .font(.system(size: 20, weight: .bold))
                    Text("Your feedback helps us improve Flow.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showSent = false }
                dismiss()
            }
        }
    }

    private func sendFeedback() {
        withAnimation(.spring(response: 0.35)) { showSent = true }
    }
}