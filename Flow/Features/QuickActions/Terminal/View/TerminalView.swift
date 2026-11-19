//
//  TerminalView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import SwiftUI

struct TerminalView: View {
    let factory: FlowViewModelFactory
    @StateObject private var store: TerminalStore
    @ObservedObject private var access = PremiumAccessManager.shared
    @Environment(\.colorScheme) private var scheme
    @FocusState private var inputFocused: Bool
    @State private var showSubscription = false
    @State private var showPremiumAlert = false

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _store = StateObject(wrappedValue: factory.makeTerminalStore())
    }

    private var bgColor: Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.055, blue: 0.075)
            : Color(uiColor: .systemBackground)
    }

    private var inputBgColor: Color {
        scheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.11)
            : Color(uiColor: .secondarySystemBackground)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            CardOverlay(state: access.overlayState, cornerRadius: 0, onAction: { showPremiumAlert = true }) {
                VStack(spacing: 0) {
                    tabBar
                    outputArea
                    inputBar
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    guard access.hasPremiumAccess else { showPremiumAlert = true; return }
                    store.addTab()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { inputFocused = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .onAppear {
            guard access.hasPremiumAccess else { showPremiumAlert = true; return }
            let needsSession = store.activeTab?.lines.isEmpty ?? true
            if needsSession {
                store.openSession(for: store.activeTab ?? TerminalTab(index: 1))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { inputFocused = true }
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack { SubscriptionView(factory: factory) }
        }
        .premiumExpiredAlert(isPresented: $showPremiumAlert, feature: "Terminal") { showSubscription = true }
    }

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.tabs) { tab in
                        TerminalTabPill(
                            tab: tab,
                            isActive: tab.id == store.activeTabID,
                            canClose: store.tabs.count > 1,
                            onTap: {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.80)) {
                                    store.activeTabID = tab.id
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { inputFocused = true }
                            },
                            onClose: { store.closeTab(id: tab.id) }
                        )
                        .id(tab.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .onChange(of: store.activeTabID) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 44)
    }

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(store.activeLines) { line in
                        TerminalLineView(line: line).id(line.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onTapGesture { inputFocused = false }
            .onChange(of: store.scrollTrigger) { _, _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Text(store.activeTab?.isRunning == true ? "…" : "❯")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.48, green: 0.25, blue: 0.95))
                .frame(width: 16)
                .animation(.easeInOut(duration: 0.12), value: store.activeTab?.isRunning)

            TextField("", text: store.activeInputBinding, prompt:
                Text("command").foregroundStyle(Color.secondary.opacity(0.40))
            )
            .font(.system(size: 15, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.asciiCapable)
            .focused($inputFocused)
            .submitLabel(.go)
            .onSubmit {
                guard !(store.activeTab?.currentInput.trimmingCharacters(in: .whitespaces).isEmpty ?? true) else { return }
                store.runActiveCommand()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { inputFocused = true }
            }

            if store.activeTab?.isRunning == true {
                ProgressView().scaleEffect(0.72)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            inputBgColor.overlay(
                Divider()
                    .frame(maxWidth: .infinity, maxHeight: 0.5)
                    .background(Color.primary.opacity(0.12)),
                alignment: .top
            )
        )
    }
}

private struct TerminalTabPill: View {
    let tab: TerminalTab
    let isActive: Bool
    let canClose: Bool
    let onTap: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    private let purple = Color(red: 0.48, green: 0.25, blue: 0.95)

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? purple : Color.secondary.opacity(0.35))
                .frame(width: 6, height: 6)

            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium, design: .monospaced))
                .foregroundStyle(isActive ? .primary : .secondary)

            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.quaternary)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive
                      ? purple.opacity(scheme == .dark ? 0.20 : 0.11)
                      : Color.primary.opacity(scheme == .dark ? 0.07 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isActive ? purple.opacity(0.40) : Color.clear, lineWidth: 0.7)
                )
        )
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.20, dampingFraction: 0.78), value: isActive)
    }
}

private struct TerminalLineView: View {
    let line: TerminalLineModel

    private var color: Color {
        switch line.kind {
        case .input:  return Color(red: 0.48, green: 0.25, blue: 0.95)
        case .output: return .primary
        case .error:  return Color(red: 0.94, green: 0.28, blue: 0.28)
        }
    }

    private var prefix: String {
        switch line.kind {
        case .input:  return "❯ "
        case .output: return "  "
        case .error:  return "✕ "
        }
    }

    var body: some View {
        Text(prefix + line.text)
            .font(.system(size: 13.5, design: .monospaced))
            .foregroundStyle(color)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(3)
    }
}

#Preview {
    NavigationStack { TerminalView() }
}
