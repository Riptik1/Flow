import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("flow.appearance") private var appearance: String = "system"
    @AppStorage("flow.subscriptionTier") private var subTier: String = "none"
    @AppStorage("flow.subscriptionEndDate") private var subEndDate: String = ""
    @State private var showSubscriptionDetail = false
    @State private var showHelp = false
    @State private var showSuggest = false
    @State private var showAboutDetail = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                appearanceSection

                subscriptionCard

                VStack(spacing: 12) {
                    settingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue) { showHelp = true }
                    settingsRow(icon: "lightbulb.fill", title: "Suggest Improvements", color: .yellow) { showSuggest = true }
                    settingsRow(icon: "info.circle.fill", title: "About", color: .gray) { showAboutDetail = true }
                }
                .padding(.horizontal, 20)

                footer
            }
            .padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showSubscriptionDetail) { SubscriptionView() }
        .navigationDestination(isPresented: $showHelp) { HelpSupportView() }
        .navigationDestination(isPresented: $showSuggest) { SuggestImprovementsView() }
        .navigationDestination(isPresented: $showAboutDetail) { AboutView() }
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appearance = mode
            }
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
        case "monthly": return "Monthly Pro"
        case "lifetime": return "Lifetime Pro"
        default: return "Free"
        }
    }

    private func settingsRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red.opacity(0.7))
            Text("Crafted with love for seamless control")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}