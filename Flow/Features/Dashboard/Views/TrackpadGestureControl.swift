//
//  TrackpadGestureControl.swift
//  Flow
//
//  Settings row that chooses how multi-finger trackpad gestures behave.
//

import SwiftUI

struct TrackpadGestureControl: View {
    @AppStorage("flow.fourFingerGestures") private var fourFingerGestures = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.purple)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.purple.opacity(0.12)))

                Text("4-Finger Gestures")
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                Toggle("", isOn: $fourFingerGestures)
                    .labelsHidden()
            }

            Text(fourFingerGestures
                 ? "4 fingers swipe to switch Spaces, open Mission Control and App Exposé. 3 fingers drag to select."
                 : "3 fingers swipe to switch Spaces, open Mission Control and App Exposé. To select, hold one finger and drag.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
