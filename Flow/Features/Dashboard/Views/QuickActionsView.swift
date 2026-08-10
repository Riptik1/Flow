import SwiftUI

struct QuickActionsView: View {
    let style: Style
    
    enum Style {
        case grid
        case row
    }
    
    let actions: [QuickAction] = [
        QuickAction(title: "Launch App", icon: "rocket.fill", color: .purple),
        QuickAction(title: "Workflows", icon: "square.3.layers.3d", color: .blue),
        QuickAction(title: "Lock Mac", icon: "lock.fill", color: .orange),
        QuickAction(title: "Mute Mac", icon: "speaker.slash.fill", color: .pink),
        QuickAction(title: "Code", icon: "chevron.left.forwardslash.chevron.right", color: .cyan),
        QuickAction(title: "Terminal", icon: "terminal.fill", color: .green),
        QuickAction(title: "Git", icon: "arrow.triangle.branch", color: .red),
        QuickAction(title: "System Info", icon: "display", color: .teal)
    ]
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Actions")
                    .font(.headline)
                
                if style == .grid {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(actions) { action in
                            QuickActionButton(action: action)
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(actions) { action in
                            QuickActionButton(action: action)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}