import Foundation

struct AppContext: Equatable {
    let bundleID: String
    let appName: String

    var isBrowser: Bool {
        ["com.apple.Safari", "com.brave.Browser", "org.mozilla.firefox",
         "com.google.Chrome", "com.microsoft.edgemac", "com.operasoftware.Opera",
         "com.vivaldi.Vivaldi", "com.apple.SafariTechnologyPreview"].contains(bundleID)
    }
    var isXcode:    Bool { bundleID == "com.apple.dt.Xcode" }
    var isVSCode:   Bool { bundleID.contains("vscode") || bundleID.contains("VSCode") }
    var isTerminal: Bool {
        ["com.apple.Terminal", "com.googlecode.iterm2",
         "com.github.wez.wezterm", "net.kovidgoyal.kitty"].contains(bundleID)
    }
    var isMail:     Bool { bundleID == "com.apple.mail" }
    var isMusic:    Bool { bundleID == "com.apple.Music" }
    var isSpotify:  Bool { bundleID == "com.spotify.client" }
    var isFinder:   Bool { bundleID == "com.apple.finder" }
    var isNotes:    Bool { bundleID == "com.apple.Notes" }
    var isSlack:    Bool { bundleID.lowercased().contains("slack") }
    var isFigma:    Bool { bundleID.lowercased().contains("figma") }
    var isPages:    Bool { bundleID == "com.apple.iWork.Pages" }
    var isMediaApp: Bool { isMusic || isSpotify }
    var wantsEmoji: Bool { isBrowser || isMail || isNotes || isPages || isSlack || bundleID.isEmpty }
}
