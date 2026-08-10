//
//  Components.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct FileRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct FileRowCompact: View {
    let file: FileItem
    let formatter: DateFormatter
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 13) {
            iconView
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .foregroundStyle(.primary)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 5) {
                    Text(formatter.string(from: file.dateModified))
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    if let size = file.size {
                        Text("·").font(.system(size: 11.5)).foregroundStyle(.tertiary)
                        Text(size).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(iconGradient).frame(width: 46, height: 46)
                .shadow(color: topColor.opacity(0.28), radius: 5, x: 0, y: 2)
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(.white)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
    }

    private var iconGradient: LinearGradient {
        LinearGradient(colors: [topColor, bottomColor], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var topColor: Color { file.kind.tileTopColor }
    private var bottomColor: Color { file.kind.tileBottomColor }
    private var iconName: String { file.kind.tileIconName }
}

struct FileRowTable: View {
    let file: FileItem
    let formatter: DateFormatter

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: tableIconName)
                    .foregroundStyle(tableColor)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28, alignment: .center)
                Text(file.name)
                    .foregroundStyle(.primary).font(.system(size: 15))
                    .lineLimit(1).truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatter.string(from: file.dateModified))
                .foregroundStyle(.secondary).font(.system(size: 14))
                .frame(width: 220, alignment: .leading)
            Text(file.sizeDisplay)
                .foregroundStyle(.secondary).font(.system(size: 14))
                .frame(width: 100, alignment: .leading)
            Text(file.kind.displayName)
                .foregroundStyle(.secondary).font(.system(size: 14))
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 12)
    }

    private var tableColor: Color {
        switch file.kind {
        case .folder: return Color(red: 0.80, green: 0.18, blue: 0.18)
        case .image:  return Color(red: 0.52, green: 0.16, blue: 0.82)
        case .video:  return Color(red: 0.90, green: 0.42, blue: 0.08)
        case .audio:  return Color(red: 0.82, green: 0.22, blue: 0.55)
        case .pdf:    return Color(red: 0.82, green: 0.14, blue: 0.14)
        default:      return Color(red: 0.22, green: 0.40, blue: 0.82)
        }
    }

    private var tableIconName: String {
        switch file.kind {
        case .folder: return "folder.fill"
        case .image:  return "photo.fill"
        case .video:  return "film.fill"
        case .audio:  return "music.note"
        case .pdf:    return "doc.richtext.fill"
        default:      return "doc.text.fill"
        }
    }
}
