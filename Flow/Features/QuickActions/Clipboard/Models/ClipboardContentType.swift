//
//  ClipboardContentType.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

extension ClipboardContentType {
    var displayName: String {
        switch self {
        case .code:     return "Code"
        case .text:     return "Text"
        case .url:      return "Link"
        case .image:    return "Image"
        case .json:     return "JSON"
        case .markdown: return "Markdown"
        case .sql:      return "SQL"
        case .other:    return "Text"
        }
    }
    
    var iconSymbol: String {
        switch self {
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .text:     return "text.alignleft"
        case .url:      return "link"
        case .image:    return "photo.fill"
        case .json:     return "doc.text.fill"
        case .markdown: return "doc.richtext.fill"
        case .sql:      return "cylinder.fill"
        case .other:    return "doc.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .code:     return Color(red: 0.44, green: 0.28, blue: 0.88)
        case .text:     return Color(red: 0.24, green: 0.52, blue: 0.95)
        case .url:      return Color(red: 0.18, green: 0.74, blue: 0.44)
        case .image:    return Color(red: 0.96, green: 0.50, blue: 0.18)
        case .json:     return Color(red: 0.92, green: 0.22, blue: 0.28)
        case .markdown: return Color(red: 0.14, green: 0.70, blue: 0.70)
        case .sql:      return Color(red: 0.62, green: 0.18, blue: 0.82)
        case .other:    return Color(red: 0.52, green: 0.52, blue: 0.58)
        }
        
    }
}
