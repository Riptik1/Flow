import SwiftUI

struct RecentFilesView: View {
    let style: Style
    
    enum Style {
        case list
        case grid
    }
    
    let files: [RecentFile] = [
        RecentFile(name: "NetworkManager.swift", path: "~/Developer/MyApp/Sources", time: "2m ago", icon: "doc.text", iconColor: .orange),
        RecentFile(name: "Project_Requirements.pdf", path: "~/Documents", time: "1h ago", icon: "doc.fill", iconColor: .red),
        RecentFile(name: "App_Design.fig", path: "~/Designs/Flow", time: "3h ago", icon: "paintbrush.fill", iconColor: .purple),
        RecentFile(name: "README.md", path: "~/Developer/Flow", time: "Yesterday", icon: "doc.text", iconColor: .blue)
    ]
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent Files")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if style == .list {
                    VStack(spacing: 12) {
                        ForEach(files) { file in
                            RecentFileRow(file: file)
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(files) { file in
                            RecentFileRow(file: file)
                        }
                    }
                }
            }
        }
    }
}