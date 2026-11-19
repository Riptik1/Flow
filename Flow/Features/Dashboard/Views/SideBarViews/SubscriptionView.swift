//
//  SubscriptionView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//

import SwiftUI

struct SubscriptionView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: SubscriptionViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var appear = false
    @ObservedObject private var access = PremiumAccessManager.shared
    @State private var selection: Int

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        let vmInstance = factory.makeSubscriptionViewModel()
        _vm = StateObject(wrappedValue: vmInstance)
        _selection = State(initialValue: vmInstance.middleSelectionIndex())
    }

    private var activeTier: PlanTier { vm.tier(atLoopIndex: selection) }

    var body: some View {
        GeometryReader { proxy in
            let isWide = hSizeClass == .regular
            let cardWidth = isWide ? min(proxy.size.width * 0.46, 420) : min(proxy.size.width * 0.82, 380)
            let cardHeight = min(proxy.size.height * 0.86, isWide ? 620 : 560)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                TabView(selection: $selection) {
                    ForEach(0..<vm.loopCount, id: \.self) { index in
                        let tier = vm.tier(atLoopIndex: index)
                        planCard(for: tier, height: cardHeight)
                            .frame(width: cardWidth)
                            .scaleEffect(selection == index ? 1.0 : 0.9)
                            .opacity(selection == index ? 1.0 : 0.45)
                            .blur(radius: selection == index ? 0 : 1.5)
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: selection)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: cardHeight + 40)

                pageIndicator
                    .padding(.top, 18)

                subscriptionFooter
                    .padding(.top, 14)

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1 : 0.96)
        }
        .background(backgroundView)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Subscription", isPresented: Binding(
            get: { vm.message != nil },
            set: { if !$0 { vm.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.message ?? "")
        }
        .onAppear {
            vm.refresh()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                appear = true
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            LinearGradient(
                colors: activeTier.gradient.map { $0.opacity(scheme == .dark ? 0.28 : 0.22) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [Color(uiColor: .systemGroupedBackground).opacity(0), Color(uiColor: .systemGroupedBackground)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.5), value: selection)
        .ignoresSafeArea()
    }

    private var subscriptionFooter: some View {
        VStack(spacing: 8) {
            if let renewal = vm.renewalText {
                Text(renewal)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if !access.isSubscribed {
                Text(access.isTrialActive
                     ? "Free access ends in \(access.trialDaysRemaining) day\(access.trialDaysRemaining == 1 ? "" : "s")"
                     : "Your free access has ended")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                Button("Restore Purchases") { vm.restore() }
                if vm.hasActiveSubscription {
                    Button("Manage / Cancel") { vm.manage() }
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .disabled(vm.isBusy)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(vm.plans, id: \.self) { tier in
                let isActive = activeTier == tier
                Capsule()
                    .fill(isActive ? Color.primary.opacity(0.85) : Color.primary.opacity(0.15))
                    .frame(width: isActive ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
            }
        }
    }

    private func planCard(for tier: PlanTier, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: tier.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: tier.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                .shadow(color: tier.gradient.first?.opacity(0.35) ?? .clear, radius: 14, y: 8)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(vm.price(for: tier))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    if let suffix = tier.priceSuffix {
                        Text(suffix)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(tier.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.top, 18)

            Divider()
                .padding(.vertical, 18)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: tier.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .opacity(0.16)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: tier.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        .frame(width: 24, height: 24)

                        Text(feature)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)

                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer(minLength: 12)

            actionButton(for: tier)
        }
        .padding(24)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(scheme == .dark ? 0.25 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(scheme == .dark ? 0.18 : 0.6), Color.white.opacity(0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.1), radius: 24, y: 14)
        .shadow(color: tier.gradient.first?.opacity(scheme == .dark ? 0.18 : 0.12) ?? .clear, radius: 30, y: 18)
    }

    @ViewBuilder
    private func actionButton(for tier: PlanTier) -> some View {
        let isCurrent = vm.subTier == tier.tierKey
        let isUnavailable = isCurrent || vm.subTier == "lifetime" || vm.isBusy

        Button {
            vm.select(tier)
        } label: {
            Text(vm.buttonLabel(for: tier, isCurrent: isCurrent))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isCurrent ? .secondary : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isCurrent
                            ? AnyShapeStyle(Color.primary.opacity(0.06))
                            : AnyShapeStyle(LinearGradient(colors: tier.gradient, startPoint: .leading, endPoint: .trailing))
                        )
                )
                .shadow(color: isCurrent ? .clear : (tier.gradient.last?.opacity(0.4) ?? .clear), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isUnavailable)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.subTier)
    }
}
