//
//  BackTapInfoCard.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

struct BackTapInfoCard: View {
    let workflow: AppWorkflow
    let accent: Color

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 20) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [accent, accent.opacity(0.72)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                            .shadow(color: accent.opacity(0.4), radius: 8, x: 0, y: 4)
                        Image(systemName: workflow.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Back Tap Shortcut")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Tap the back of your iPhone while Flow is open to instantly launch this workflow on your Mac.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.yellow)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tips for best results:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("• Tap firmly with the tip of your finger\n• Tap the middle or lower back of your iPhone\n• Keep the phone still while tapping\n• 3 or 4 taps work more reliably than 2")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.yellow.opacity(0.08)))
            }
        }
    }
}

struct BackTapSystemConflictCard: View {
    var body: some View {
        GlassCard(cornerRadius: 18, padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Avoid system Back Tap conflict")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("If iOS Back Tap (Settings → Accessibility → Touch → Back Tap) is set to 2 taps, it may conflict. We recommend using 3 or 4 taps in Flow, or turning off the iOS system Back Tap.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2.5)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Open Settings")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
    }
}

struct BackTapToggleCard: View {
    @ObservedObject var vm: BackTapShortcutViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 0) {
            Toggle(isOn: Binding(
                get: { vm.isEnabled },
                set: { val in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.setEnabled(val)
                    }
                }
            )) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(vm.isEnabled ? vm.accent.opacity(0.18) : Color.primary.opacity(0.08))
                            .frame(width: 42, height: 42)
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(vm.isEnabled ? vm.accent : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable Back Tap")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Detect taps on the back of iPhone")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(vm.accent)
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
    }
}

struct BackTapPickerSection: View {
    @ObservedObject var vm: BackTapShortcutViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap Count")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(BackTapKind.allCases, id: \.self) { kind in
                    tapCard(kind)
                }
            }
        }
    }

    private func tapCard(_ kind: BackTapKind) -> some View {
        let taken    = vm.isTaken(kind)
        let isChosen = vm.selectedKind == kind && !taken
        return Button {
            vm.selectKind(kind)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isChosen ? vm.accent : Color.primary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    if isChosen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(vm.numStr(kind))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(taken ? .tertiary : .secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(kind.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(taken ? .tertiary : .primary)
                        if kind != .doubleTap {
                            Text("Recommended")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(vm.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(vm.accent.opacity(0.15)))
                        }
                    }
                    Text(taken ? "Used by another workflow" : vm.kindDesc(kind))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                dots(kind, active: isChosen).opacity(taken ? 0.3 : 1.0)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isChosen
                      ? vm.accent.opacity(scheme == .dark ? 0.15 : 0.09)
                      : Color.primary.opacity(scheme == .dark ? 0.06 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isChosen ? vm.accent.opacity(0.45) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(taken)
        .opacity(taken ? 0.5 : 1.0)
    }

    private func dots(_ kind: BackTapKind, active: Bool) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<vm.kindCount(kind), id: \.self) { _ in
                Circle()
                    .fill(active ? vm.accent : Color.secondary.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct BackTapTestSection: View {
    @ObservedObject var vm: BackTapShortcutViewModel

    var body: some View {
        let needed = vm.kindCount(vm.selectedKind)
        return GlassCard(cornerRadius: 18, padding: 20) {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(vm.accent.opacity(0.12))
                            .frame(width: 52, height: 52)
                            .scaleEffect(vm.ripple ? 1.8 : 1.0)
                            .opacity(vm.ripple ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 0.6), value: vm.ripple)

                        Circle()
                            .fill(vm.rawPulse ? vm.accent.opacity(0.35) : vm.accent.opacity(0.18))
                            .frame(width: 52, height: 52)
                            .scaleEffect(vm.rawPulse ? 1.1 : 1.0)
                            .animation(.spring(response: 0.12, dampingFraction: 0.6), value: vm.rawPulse)

                        Image(systemName: "waveform.path")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(vm.rawPulse ? vm.accent : vm.accent.opacity(0.7))
                            .animation(.spring(response: 0.12, dampingFraction: 0.6), value: vm.rawPulse)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Test")
                            .font(.system(size: 15, weight: .bold))
                        Text("Tap the back of your iPhone \(vm.numStr(vm.selectedKind)) times")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        if vm.testTapCount > 0 {
                            Text("\(vm.testTapCount) of \(needed) taps detected")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(vm.accent)
                                .transition(.opacity.animation(.easeIn(duration: 0.1)))
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(0..<needed, id: \.self) { i in
                        Capsule()
                            .fill(i < vm.testTapCount ? vm.accent : vm.accent.opacity(0.18))
                            .frame(height: 10)
                            .scaleEffect(y: i < vm.testTapCount ? 1.0 : 0.7)
                            .animation(
                                .spring(response: 0.18, dampingFraction: 0.55)
                                    .delay(Double(i) * 0.04),
                                value: vm.testTapCount
                            )
                    }
                }
                .frame(height: 14)
            }
        }
    }
}

struct BackTapToastView: View {
    let message: String
    let success: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(success ? .green : .orange)
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(Capsule().fill(Color(white: 0.12)))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            .padding(.bottom, 50)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
