//
//  SubscriptionView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//


import SwiftUI

struct SubscriptionView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flow.subscriptionTier") private var subTier: String = "none"
    @AppStorage("flow.subscriptionEndDate") private var subEndDate: String = ""
    @State private var appear = false
    @State private var badgePulse = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Choose Your Plan")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Unlock the full potential of Flow")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    freeCard
                    monthlyCard
                    lifetimeCard
                }
                .padding(.horizontal, 20)

                Button {
                    restorePurchases()
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 40)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                badgePulse = true
            }
        }
    }

    private var freeCard: some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Free")
                            .font(.system(size: 22, weight: .bold))
                        Text("Basic remote control")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$0")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                .padding(.top, 4)

                Divider().padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow("Basic remote control", active: true)
                    featureRow("Trackpad & keyboard", active: true)
                    featureRow("3 Workflows", active: true)
                    featureRow("File access", active: true)
                    featureRow("Spotlight search", active: false)
                    featureRow("Voice commands", active: false)
                    featureRow("Custom themes", active: false)
                    featureRow("Priority support", active: false)
                }

                Button {
                    selectTier("none")
                } label: {
                    Text("Current Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .disabled(subTier == "none")
                .padding(.top, 16)
            }
        }
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
    }

    private var monthlyCard: some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MOST POPULAR")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                                .opacity(badgePulse ? 1.0 : 0.7)
                        )
                    Spacer()
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly")
                            .font(.system(size: 22, weight: .bold))
                        Text("Full access, cancel anytime")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("$4.99")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("/month")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)

                Divider().padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow("Everything in Free", active: true)
                    featureRow("Unlimited workflows", active: true)
                    featureRow("Advanced trackpad gestures", active: true)
                    featureRow("Spotlight search", active: true)
                    featureRow("Voice commands", active: true)
                    featureRow("Custom themes", active: true)
                    featureRow("Priority support", active: true)
                    featureRow("No ads", active: true)
                }

                Button {
                    purchaseMonthly()
                } label: {
                    Text(subTier == "monthly" ? "Subscribed" : "Subscribe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    subTier == "monthly"
                                    ? AnyShapeStyle(Color.green)
                                    : AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.blue.opacity(0.5), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1.0 : 0.95)
        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.15), value: appear)
    }

    private var lifetimeCard: some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("BEST VALUE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange))
                    Spacer()
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lifetime")
                            .font(.system(size: 22, weight: .bold))
                        Text("Pay once, own forever")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("$49.99")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("one-time")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)

                Divider().padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow("Everything in Monthly", active: true)
                    featureRow("All future updates", active: true)
                    featureRow("Lifetime priority support", active: true)
                    featureRow("Early access to features", active: true)
                }

                Button {
                    purchaseLifetime()
                } label: {
                    Text(subTier == "lifetime" ? "Owned" : "Purchase")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    subTier == "lifetime"
                                    ? AnyShapeStyle(Color.green)
                                    : AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.orange.opacity(0.5), .red.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25), value: appear)
    }

    private func featureRow(_ text: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: active ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(active ? .green : .secondary.opacity(0.4))
            Text(text)
                .font(.system(size: 14, weight: active ? .medium : .regular))
                .foregroundStyle(active ? .primary : .secondary)
            Spacer()
        }
    }

    private func selectTier(_ tier: String) {
        subTier = tier
        if tier == "none" {
            subEndDate = ""
        }
    }

    private func purchaseMonthly() {
        subTier = "monthly"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        subEndDate = formatter.string(from: endDate)
    }

    private func purchaseLifetime() {
        subTier = "lifetime"
        subEndDate = ""
    }

    private func restorePurchases() {
        subTier = "none"
        subEndDate = ""
    }
}