//
//  SpotlightOverlay.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

struct SpotlightOverlay: View {
    @ObservedObject var vm: SpotlightViewModel
    var spotlightFocused: FocusState<Bool>.Binding
    let onDismiss: () -> Void
    let onOpen: (SpotlightResult) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                VStack(spacing: 0) {
                    HStack(spacing: 11) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(red: 0.48, green: 0.25, blue: 0.95))

                        TextField("Search apps, files, folders...", text: $vm.query)
                            .font(.system(size: 17, weight: .medium))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused(spotlightFocused)
                            .submitLabel(.search)
                            .onSubmit { vm.search() }
                            .onChange(of: vm.query) { _, _ in vm.scheduleSearch() }

                        if !vm.query.isEmpty {
                            Button { vm.reset() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if vm.isSearching { ProgressView().scaleEffect(0.75) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)

                    if !vm.results.isEmpty {
                        Divider().opacity(0.35)
                        resultsList
                    } else if !vm.query.isEmpty && !vm.isSearching {
                        HStack {
                            Text("No results").font(.system(size: 14)).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(scheme == .dark
                                      ? Color(red: 0.09, green: 0.09, blue: 0.13).opacity(0.82)
                                      : Color.white.opacity(0.75))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.16 : 0.65), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 48, x: 0, y: 24)
                )
                .padding(.horizontal, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
                .clipped()

                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(vm.results.enumerated()), id: \.element.id) { index, result in
                    Button {
                        onOpen(result)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 13) {
                            SpotlightIconView(result: result).frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary).lineLimit(1)
                                Text(result.path).font(.system(size: 11)).foregroundStyle(.tertiary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Text(result.kind).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.primary.opacity(0.07)))
                        }
                        .padding(.horizontal, 18).padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    if index < vm.results.count - 1 {
                        Divider().padding(.leading, 67).opacity(0.25)
                    }
                }
            }
        }
        .frame(maxHeight: 360)
    }
}

private struct SpotlightIconView: View {
    let result: SpotlightResult
    @State private var uiImage: UIImage? = nil

    var body: some View {
        ZStack {
            if let img = uiImage {
                Image(uiImage: img).resizable().interpolation(.high).scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.opacity.animation(.easeIn(duration: 0.15)))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fallbackGradient)
                    .overlay(Image(systemName: fallbackIcon)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white))
            }
        }
        .onAppear {
            guard let data = result.iconPNG else { return }
            Task.detached(priority: .userInitiated) {
                let img = UIImage(data: data)
                await MainActor.run { uiImage = img }
            }
        }
    }

    private var fallbackIcon: String {
        switch result.kind {
        case "Application": return "app.fill"
        case "Document":    return "doc.fill"
        case "Image":       return "photo.fill"
        case "Video":       return "film.fill"
        case "Audio":       return "music.note"
        case "Archive":     return "archivebox.fill"
        default:            return "doc.fill"
        }
    }

    private var fallbackGradient: LinearGradient {
        let colors: [Color]
        switch result.kind {
        case "Application": colors = [Color(red: 0.75, green: 0.20, blue: 0.95), Color(red: 0.45, green: 0.08, blue: 0.72)]
        case "Document":    colors = [Color(red: 0.10, green: 0.52, blue: 0.92), Color(red: 0.05, green: 0.30, blue: 0.70)]
        case "Image":       colors = [Color(red: 0.18, green: 0.72, blue: 0.42), Color(red: 0.06, green: 0.48, blue: 0.26)]
        case "Video":       colors = [Color(red: 0.95, green: 0.28, blue: 0.28), Color(red: 0.70, green: 0.08, blue: 0.08)]
        case "Audio":       colors = [Color(red: 0.90, green: 0.20, blue: 0.48), Color(red: 0.65, green: 0.05, blue: 0.28)]
        default:            colors = [Color(red: 0.55, green: 0.55, blue: 0.60), Color(red: 0.35, green: 0.35, blue: 0.40)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
