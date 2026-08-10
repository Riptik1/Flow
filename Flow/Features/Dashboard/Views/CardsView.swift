//
//  KeyboardCard 2.swift
//  Flow
//
//  Created by Riptik Jhajhria on 11/05/26.
//

import SwiftUI

struct KeyboardCard: View {
    
    var body: some View {
        NavigationLink {
            MacKeyboardView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("with Touch Bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer(minLength: 0)
                    
                    Image("keyboard")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.2)
                        .frame(height: 95)
                        .padding(.bottom, -24)
                        .shadow(color: .blue.opacity(0.12), radius: 10, x: 0, y: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FilesCard: View {
    
    var body: some View {
        NavigationLink {
            FileView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Files")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Browse Mac files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        Spacer()
                        Image(systemName: "folder.fill")
                            .font(.system(size: 60, weight: .regular))
                            .foregroundStyle(.blue)
                            .shadow(color: .blue.opacity(0.23), radius: 12, x: 2, y: 6)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct TrackpadCard: View {

    var body: some View {
        NavigationLink {
            TrackpadView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trackpad")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Swipe, haptics and gesture")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image("trackpad")
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(1.1)
                        .shadow(color: .blue.opacity(0.11), radius: 12, x: 2, y: 6)
                        .padding(.bottom, -25)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrackpadCard()
}

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
    }
}

#Preview {
    KeyboardCard()
    FilesCard()
}
