import SwiftUI

struct TrackpadSpeedControl: View {
    @AppStorage("flow.trackpadSpeed") private var trackpadSpeed: Double = 0.5
    @State private var liveValue: Double = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.blue.opacity(0.12)))

                    Text("Trackpad Speed")
                        .font(.system(size: 15, weight: .medium))
                }

                Spacer()

                Text(speedLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
                    .animation(nil, value: liveValue)
            }

            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Slider(
                    value: $liveValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing { trackpadSpeed = liveValue }
                    }
                )
                .tint(.blue)

                Image(systemName: "hare.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            liveValue = trackpadSpeed
        }
    }

    private var speedLabel: String {
        switch liveValue {
        case ..<0.34: return "Slow"
        case ..<0.67: return "Normal"
        default: return "Fast"
        }
    }
}
