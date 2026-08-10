//
//  WorkflowNamingView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

struct WorkflowNamingView: View {
    let factory: FlowViewModelFactory
    var onSave: (AppWorkflow) -> Void
    var onBack: () -> Void

    @StateObject private var vm: WorkflowNamingViewModel
    @FocusState private var nameFocused: Bool
    @Environment(\.colorScheme) private var scheme

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    init(existingWorkflow: AppWorkflow?, selectedBundleIDs: [String],
         factory: FlowViewModelFactory = ViewModelFactory.shared,
         onSave: @escaping (AppWorkflow) -> Void, onBack: @escaping () -> Void) {
        self.factory = factory
        self.onSave = onSave
        self.onBack = onBack
        _vm = StateObject(wrappedValue: factory.makeWorkflowNamingViewModel(
            existingWorkflow: existingWorkflow, selectedBundleIDs: selectedBundleIDs))
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    bigIconPreview
                        .padding(.top, 24)
                    nameField
                    colorRow
                    iconGrid
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, isPad ? 40 : 20)
                .padding(.bottom, 110)
            }

            VStack {
                Spacer()
                saveButton
                    .padding(.horizontal, isPad ? 40 : 20)
                    .padding(.bottom, 28)
            }
        }
        .navigationTitle(vm.existingWorkflow == nil ? "Name Workflow" : "Edit Workflow")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        Text("Apps").font(.system(size: 16))
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { nameFocused = true }
        }
    }

    private var bigIconPreview: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(
                        colors: [vm.accentColor, vm.accentColor.opacity(0.72)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: vm.accentColor.opacity(0.5), radius: 20, x: 0, y: 10)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(stops: [.init(color: .white.opacity(0.30), location: 0), .init(color: .clear, location: 0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 96, height: 96)
                Image(systemName: vm.selectedIcon)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.selectedIcon)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.selectedColorHex)

            Text(vm.workflowName.isEmpty ? "Workflow Name" : vm.workflowName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(vm.workflowName.isEmpty ? .tertiary : .primary)
                .animation(.easeInOut(duration: 0.15), value: vm.workflowName)

            Text("\(vm.selectedBundleIDs.count) app\(vm.selectedBundleIDs.count == 1 ? "" : "s") selected")
                .font(.system(size: 14)).foregroundStyle(.secondary)
        }
    }

    private var nameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil").font(.system(size: 16, weight: .medium)).foregroundStyle(vm.accentColor)
            TextField("e.g. Coding Setup…", text: $vm.workflowName)
                .font(.system(size: 17))
                .focused($nameFocused)
                .submitLabel(.done)
            if !vm.workflowName.isEmpty {
                Button { vm.workflowName = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(scheme == .dark ? 0.08 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(vm.accentColor.opacity(nameFocused ? 0.6 : 0), lineWidth: 1.5))
        .animation(.easeInOut(duration: 0.2), value: nameFocused)
    }

    private var colorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(WorkflowIconCatalog.colorPairs, id: \.top) { pair in
                    let isSelected = vm.selectedColorHex == pair.top
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            vm.selectedColorHex = pair.top
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: pair.top), Color(hex: pair.bottom)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                                .shadow(color: Color(hex: pair.top).opacity(0.5), radius: 6, x: 0, y: 3)
                            if isSelected {
                                Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 36, height: 36)
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 4)
        }
    }

    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isPad ? 8 : 5),
                spacing: 14
            ) {
                ForEach(WorkflowIconCatalog.icons, id: \.symbol) { item in
                    let isSelected = vm.selectedIcon == item.symbol
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { vm.selectedIcon = item.symbol }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(isSelected ? vm.accentColor : Color.primary.opacity(scheme == .dark ? 0.10 : 0.07))
                                    .frame(width: 52, height: 52)
                                    .shadow(color: isSelected ? vm.accentColor.opacity(0.45) : .clear, radius: 8, x: 0, y: 4)
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(LinearGradient(stops: [.init(color: .white.opacity(0.28), location: 0), .init(color: .clear, location: 0.6)], startPoint: .top, endPoint: .bottom))
                                        .frame(width: 52, height: 52)
                                }
                                Image(systemName: item.symbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : .secondary)
                            }
                            Text(item.label)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(isSelected ? vm.accentColor : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                    .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isSelected)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            guard vm.canSave else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSave(vm.buildWorkflow())
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
                Text(vm.existingWorkflow == nil ? "Save Workflow" : "Update Workflow").font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(vm.canSave
                    ? LinearGradient(colors: [vm.accentColor, vm.accentColor.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.secondary.opacity(0.3), .secondary.opacity(0.3)], startPoint: .leading, endPoint: .trailing)))
            .shadow(color: vm.canSave ? vm.accentColor.opacity(0.42) : .clear, radius: 14, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canSave)
        .animation(.easeInOut(duration: 0.2), value: vm.canSave)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.selectedColorHex)
    }
}

#Preview {
    WorkflowNamingView(existingWorkflow: nil, selectedBundleIDs: ["com.apple.Safari", "com.apple.Notes"], onSave: { _ in }, onBack: {})
}
