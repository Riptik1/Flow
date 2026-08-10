//
//  FileKind.swift
//  Flow
//
//  Created by Riptik Jhajhria on 03/07/26.
//

import Foundation
import SwiftUI

enum FileKind {
    case folder
    case image
    case video
    case audio
    case pdf
    case document
    case spreadsheet
    case archive
    case code
    case plainText
    case other

    var displayName: String {
        switch self {
        case .folder: return "Folder"
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .pdf: return "PDF"
        case .document: return "Document"
        case .spreadsheet: return "Spreadsheet"
        case .archive: return "Archive"
        case .code: return "Code"
        case .plainText: return "Text"
        case .other: return "File"
        }
    }
}

struct LargeFileAlertInfo: Identifiable {
    let id = UUID()
    let fileName: String
    let fileSize: String
    let filePath: String
}

extension FileKind {
    var tileTopColor: Color {
        switch self {
        case .folder:      return Color(red: 0.80, green: 0.18, blue: 0.18)
        case .image:       return Color(red: 0.52, green: 0.16, blue: 0.82)
        case .video:       return Color(red: 0.90, green: 0.42, blue: 0.08)
        case .audio:       return Color(red: 0.82, green: 0.22, blue: 0.55)
        case .pdf:         return Color(red: 0.82, green: 0.14, blue: 0.14)
        case .document:    return Color(red: 0.18, green: 0.42, blue: 0.85)
        case .spreadsheet: return Color(red: 0.12, green: 0.58, blue: 0.28)
        case .archive:     return Color(red: 0.55, green: 0.36, blue: 0.12)
        case .code:        return Color(red: 0.88, green: 0.44, blue: 0.10)
        case .plainText:   return Color(red: 0.22, green: 0.40, blue: 0.82)
        case .other:       return Color(red: 0.40, green: 0.40, blue: 0.44)
        }
    }

    var tileBottomColor: Color {
        switch self {
        case .folder:      return Color(red: 0.60, green: 0.08, blue: 0.08)
        case .image:       return Color(red: 0.36, green: 0.08, blue: 0.65)
        case .video:       return Color(red: 0.70, green: 0.28, blue: 0.02)
        case .audio:       return Color(red: 0.62, green: 0.10, blue: 0.38)
        case .pdf:         return Color(red: 0.62, green: 0.05, blue: 0.05)
        case .document:    return Color(red: 0.08, green: 0.26, blue: 0.68)
        case .spreadsheet: return Color(red: 0.06, green: 0.42, blue: 0.18)
        case .archive:     return Color(red: 0.38, green: 0.22, blue: 0.05)
        case .code:        return Color(red: 0.68, green: 0.28, blue: 0.02)
        case .plainText:   return Color(red: 0.08, green: 0.24, blue: 0.65)
        case .other:       return Color(red: 0.24, green: 0.24, blue: 0.28)
        }
    }

    var tileIconName: String {
        switch self {
        case .folder:      return "folder.fill"
        case .image:       return "photo.fill"
        case .video:       return "film.fill"
        case .audio:       return "music.note"
        case .pdf:         return "doc.richtext.fill"
        case .document:    return "doc.text.fill"
        case .spreadsheet: return "tablecells.fill"
        case .archive:     return "archivebox.fill"
        case .code:        return "chevron.left.forwardslash.chevron.right"
        case .plainText:   return "doc.text.fill"
        case .other:       return "doc.fill"
        }
    }
}
