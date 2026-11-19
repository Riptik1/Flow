//
//  WorkflowsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import SwiftUI

struct WorkflowsView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: WorkflowsViewModel

    @State private var showPicker          = false
    @State private var editingWorkflow: AppWorkflow?  = nil
    @State private var workflowToDelete: AppWorkflow? = nil
    @State private var showDeleteAlert     = false
    @State private var backTapWorkflow: AppWorkflow?  = nil
    @ObservedObject private var access = PremiumAccessManager.shared
    @State private var showPremiumAlert = false
    @State private var showSubscription = false

    @Environment(\.colorScheme) private var scheme
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeWorkflowsViewModel())
    }

    var body: some View {
        CardOverlay(state: access.overlayState, cornerRadius: 0, onAction: { showPremiumAlert = true }) {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                if vm.workflows.isEmpty { emptyState } else { workflowList }
            }
        }
        .premiumExpiredAlert(isPresented: $showPremiumAlert, feature: "Workflows") { showSubscription = true }
        .sheet(isPresented: $showSubscription) {
            NavigationStack { SubscriptionView(factory: factory) }
        }
        .onAppear { if !access.hasPremiumAccess { showPremiumAlert = true } }
        .navigationTitle("Workflows")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    guard access.hasPremiumAccess else { showPremiumAlert = true; return }
                    editingWorkflow = nil
                    showPicker = true
                } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .fullScreenCover(isPresented: $showPicker) {
            WorkflowCreatorFlow(
                existingWorkflow: editingWorkflow,
                factory: factory,
                onSave: { wf in
                    if editingWorkflow != nil { vm.update(wf) } else { vm.add(wf) }
                    editingWorkflow = nil
                    showPicker = false
                },
                onCancel: {
                    editingWorkflow = nil
                    showPicker = false
                }
            )
        }
        .alert("Delete Workflow", isPresented: $showDeleteAlert, presenting: workflowToDelete) { wf in
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.delete(wf) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { wf in
            Text("Delete \"\(wf.name)\"?")
        }
        .onAppear {
            AppRepository.shared.prefetchIfNeeded()
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 32)
                GlassCard(cornerRadius: 22, padding: 28) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "7D32F5").opacity(0.25), Color(hex: "3B82F6").opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 76, height: 76)
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(hex: "7D32F5"), Color(hex: "3B82F6")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        VStack(spacing: 8) {
                            Text("Create Your First Workflow")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                            Text("Workflows let you launch a group of apps on your Mac all at once — perfect for your coding environment, design workspace, or morning routine.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        VStack(spacing: 10) {
                            EmptyChip(icon: "chevron.left.forwardslash.chevron.right", color: Color(hex: "3B82F6"), title: "Coding Setup",      subtitle: "VS Code + Terminal + Simulator")
                            EmptyChip(icon: "paintbrush.fill",                         color: Color(hex: "EC4899"), title: "Design Workflow",   subtitle: "Figma + Photoshop + Browser")
                            EmptyChip(icon: "briefcase.fill",                          color: Color(hex: "7D32F5"), title: "Work Productivity", subtitle: "Slack + Notion + Chrome")
                        }
                        Button {
                            editingWorkflow = nil
                            showPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 16, weight: .semibold))
                                Text("Create Workflow").font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Color(hex: "7D32F5"), Color(hex: "5B10C4")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .shadow(color: Color(hex: "7D32F5").opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 40)
            }
        }
    }

    private var workflowList: some View {
        ScrollView(showsIndicators: false) {
            if isPad {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(vm.workflows) { wf in cardView(wf) }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 32)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(vm.workflows) { wf in cardView(wf) }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
            }
        }
    }

    private func cardView(_ wf: AppWorkflow) -> some View {
        WorkflowCard(
            workflow: wf,
            factory: factory,
            onTap:     { vm.launch(wf) },
            onEdit:    { editingWorkflow = wf; showPicker = true },
            onDelete:  { workflowToDelete = wf; showDeleteAlert = true }
        )
    }
}

private struct EmptyChip: View {
    let icon: String; let color: Color; let title: String; let subtitle: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(scheme == .dark ? 0.06 : 0.04)))
    }
}

struct WorkflowCard: View {
    let workflow:   AppWorkflow
    let factory: FlowViewModelFactory
    let onTap:     () -> Void
    let onEdit:    () -> Void
    let onDelete:  () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isPad:    Bool    { UIDevice.current.userInterfaceIdiom == .pad }
    private var iconSize: CGFloat { isPad ? 48 : 44 }
    private var corner:   CGFloat { iconSize * 0.224 }
    private let maxVisible = 6

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 0) {
            Button(action: onTap) { cardContent }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .contextMenu {
                    Button { onEdit()    } label: { Label("Edit Workflow",     systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(hex: workflow.iconColorHex), Color(hex: workflow.iconColorHex).opacity(0.72)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                        .shadow(color: Color(hex: workflow.iconColorHex).opacity(0.5), radius: 10, x: 0, y: 5)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            stops: [.init(color: .white.opacity(0.28), location: 0), .init(color: .clear, location: 0.55)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 54, height: 54)
                    Image(systemName: workflow.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(workflow.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(workflow.appBundleIDs.count) app\(workflow.appBundleIDs.count == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        if workflow.backTapEnabled {
                            HStack(spacing: 3) {
                                Image(systemName: "hand.tap.fill").font(.system(size: 9, weight: .bold))
                                Text(workflow.backTapKind.rawValue).font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: workflow.iconColorHex))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: workflow.iconColorHex).opacity(0.15)))
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 18)

            appIconStrip
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var appIconStrip: some View {
        if workflow.appBundleIDs.isEmpty {
            Text("No apps").font(.system(size: 12)).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            let visible  = Array(workflow.appBundleIDs.prefix(maxVisible))
            let overflow = workflow.appBundleIDs.count - maxVisible

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    ForEach(visible, id: \.self) { bundleID in
                        CachedAppIconView(bundleID: bundleID, size: iconSize, cornerRadius: corner, factory: factory)
                    }
                    if overflow > 0 {
                        ZStack {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .fill(Color.primary.opacity(0.11))
                            Text("+\(overflow)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: iconSize, height: iconSize)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: corner + 8, style: .continuous)
                        .fill(.thinMaterial)
                        .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.18), radius: 24, x: 0, y: 10)
                        .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.08), radius: 6, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: corner + 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.14 : 0.08), lineWidth: 0.7)
                        )
                )
            }
        }
    }
}

#Preview { NavigationStack { WorkflowsView() } }
