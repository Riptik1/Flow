//
//  SettingsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("flow.appearance") private var appearance: String = "system"
    @AppStorage("flow.subscriptionTier") private var subTier: String = "none"
    @AppStorage("flow.subscriptionEndDate") private var subEndDate: String = ""
    @AppStorage("flow.inputMode") private var inputMode: String = "trackpad"
    @State private var showSubscriptionDetail = false
    @State private var showSuggest = false

    private var isPad: Bool { hSizeClass == .regular }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                appearanceSection

                controlSection

                subscriptionCard

                VStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "mailto:riptikjhajhria0987@gmail.com") {
                            openURL(url)
                        }
                    } label: {
                        settingsRowContent(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue)
                    }
                    .buttonStyle(.plain)

                    Button { showSuggest = true } label: {
                        settingsRowContent(icon: "lightbulb.fill", title: "Suggest Improvements", color: .yellow)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                aboutCard

                footer
            }
            .padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSubscriptionDetail) { SubscriptionView() }
        .navigationDestination(isPresented: $showSuggest) { SuggestImprovementsView() }
    }

    private var appearanceSection: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Appearance")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 4) {
                    appearanceButton(mode: "light", icon: "sun.max.fill", label: "Light")
                    appearanceButton(mode: "system", icon: "circle.lefthalf.filled", label: "System")
                    appearanceButton(mode: "dark", icon: "moon.fill", label: "Dark")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func appearanceButton(mode: String, icon: String, label: String) -> some View {
        let isSelected = appearance == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { appearance = mode }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var controlSection: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Control")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                TrackpadSpeedControl()

                if isPad {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.purple)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.purple.opacity(0.12)))

                            Text("Input Mode")
                                .font(.system(size: 15, weight: .medium))

                            Spacer()
                        }

                        HStack(spacing: 4) {
                            inputModeButton(mode: "trackpad", icon: "trackpad", label: "Trackpad")
                            inputModeButton(mode: "keyboardTrackpad", icon: "keyboard.badge.eye", label: "Keyboard + Trackpad")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func inputModeButton(mode: String, icon: String, label: String) -> some View {
        let isSelected = inputMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { inputMode = mode }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.purple : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var subscriptionCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            subTier == "none"
                            ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                    Image(systemName: subTier == "none" ? "crown.fill" : "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    if subTier == "none" {
                        Text("Flow Pro")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Unlock all features")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(tierDisplayName)
                            .font(.system(size: 17, weight: .semibold))
                        if !subEndDate.isEmpty {
                            Text("Expires on \(subEndDate)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Active and fully unlocked")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .onTapGesture { showSubscriptionDetail = true }
    }

    private var tierDisplayName: String {
        switch subTier {
        case "weekly": return "Weekly Pro"
        case "monthly": return "Monthly Pro"
        case "lifetime": return "Lifetime Pro"
        default: return "Free"
        }
    }

    private func settingsRowContent(icon: String, title: String, color: Color) -> some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(color.opacity(0.12)))

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutCard: some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            HStack {
                Image("AppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Flow")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Version 1.0.0")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red.opacity(0.7))
            Text("Built with care, so your Mac feels closer than ever")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
