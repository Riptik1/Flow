//
//  SuggestImprovementsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//

import SwiftUI

struct SuggestImprovementsView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: SuggestImprovementsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeSuggestImprovementsViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.bottom, 6)

                        Text("Suggest Improvements")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text("Got an idea that would make Flow better? We're all ears.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    GlassCard(cornerRadius: 18, padding: 4) {
                        ZStack(alignment: .topLeading) {
                            if vm.feedback.isEmpty {
                                Text("Tell us what's on your mind — new features, fixes, anything at all...")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $vm.feedback)
                                .font(.system(size: 16))
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                                .focused($isFocused)
                        }
                        .frame(minHeight: 160)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isFocused ? Color.blue.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: isFocused ? 1.5 : 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)
                }
            }

            Button {
                withAnimation(.spring(response: 0.35)) { vm.sendFeedback() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Send Feedback")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            vm.canSend
                            ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.secondary.opacity(0.3))
                        )
                )
            }
            .disabled(!vm.canSend)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.showSent {
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
                    Text("Thanks for the idea!")
                        .font(.system(size: 20, weight: .bold))
                    Text("Every suggestion helps shape what Flow becomes next.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { vm.showSent = false }
                dismiss()
            }
        }
    }
}
