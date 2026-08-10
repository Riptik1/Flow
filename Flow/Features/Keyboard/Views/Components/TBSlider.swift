//
//  TBSlider.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct TBSlider: View {
    let icon0: String; let icon1: String
    let tbH: CGFloat; let dark: Bool; let initial: CGFloat
    let onDown: () -> Void; let onUp: () -> Void

    @State private var ratio:    CGFloat
    @State private var lastStep: Int
    @State private var dragging = false

    private static let steps = 16
    private var thumbD: CGFloat { max(16.0, tbH * 0.56) }
    private var trackW: CGFloat { max(80.0, tbH * 2.8) }
    private var trackH: CGFloat { max(4.0,  tbH * 0.13) }
    private var iconSz: CGFloat { max(10.0, tbH * 0.30) }
    private var iconFg: Color   { dark ? .white.opacity(0.85) : Color(white: 0.15) }
    private var trackBg: Color  { dark ? .white.opacity(0.20) : Color(white: 0.52).opacity(0.45) }
    private var fillC:  Color   { dark ? Color(red: 0.28, green: 0.62, blue: 1.0) : Color(red: 0.12, green: 0.48, blue: 0.95) }

    init(icon0: String, icon1: String, tbH: CGFloat, dark: Bool, initial: CGFloat = 0.5,
         onDown: @escaping () -> Void, onUp: @escaping () -> Void) {
        self.icon0 = icon0; self.icon1 = icon1; self.tbH = tbH; self.dark = dark
        self.initial = initial; self.onDown = onDown; self.onUp = onUp
        _ratio    = State(initialValue: initial)
        _lastStep = State(initialValue: Int((initial * CGFloat(TBSlider.steps)).rounded()))
    }

    var body: some View {
        HStack(spacing: 5.0) {
            Button { tap(up: false) } label: {
                Image(systemName: icon0)
                    .font(.system(size: iconSz, weight: .semibold))
                    .foregroundStyle(iconFg)
                    .frame(width: thumbD, height: thumbD)
                    .contentShape(Rectangle())
            }.buttonStyle(TBPressStyle())

            GeometryReader { g in
                let tw: CGFloat = g.size.width
                let usable: CGFloat = max(1.0, tw - thumbD)
                let tx: CGFloat = (thumbD / 2.0) + (ratio * usable)
                let shadowR: CGFloat = dragging ? 5.0 : 3.0
                let shadowY: CGFloat = dragging ? 2.0 : 1.5
                let shadowOp: Double = dragging ? 0.38 : 0.26
                let thumbScale: CGFloat = dragging ? 1.07 : 1.0
                ZStack(alignment: .leading) {
                    Capsule().fill(trackBg).frame(height: trackH)
                    Capsule().fill(fillC).frame(width: max(trackH, tx), height: trackH)
                    Circle().fill(Color.white)
                        .frame(width: thumbD, height: thumbD)
                        .shadow(color: .black.opacity(shadowOp), radius: shadowR, x: 0.0, y: shadowY)
                        .scaleEffect(thumbScale)
                        .animation(.easeOut(duration: 0.09), value: dragging)
                        .offset(x: tx - (thumbD / 2.0))
                }
                .contentShape(Rectangle())
                .highPriorityGesture(DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        if !dragging {
                            dragging = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        let newRatio = max(0.0, min(1.0, (v.location.x - (thumbD / 2.0)) / usable))
                        ratio = newRatio
                        let newStep = Int((newRatio * CGFloat(Self.steps)).rounded())
                        let delta = newStep - lastStep
                        if delta != 0 {
                            for _ in 0..<abs(delta) { delta > 0 ? onUp() : onDown() }
                            UISelectionFeedbackGenerator().selectionChanged()
                            lastStep = newStep
                        }
                    }
                    .onEnded { _ in
                        dragging = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
            }
            .frame(width: trackW, height: thumbD)

            Button { tap(up: true) } label: {
                Image(systemName: icon1)
                    .font(.system(size: iconSz * 1.1, weight: .semibold))
                    .foregroundStyle(iconFg)
                    .frame(width: thumbD, height: thumbD)
                    .contentShape(Rectangle())
            }.buttonStyle(TBPressStyle())
        }
        .padding(.horizontal, 3.0)
    }

    private func tap(up: Bool) {
        let step = 1.0 / CGFloat(Self.steps)
        ratio = max(0.0, min(1.0, ratio + (up ? step : -step)))
        lastStep = Int((ratio * CGFloat(Self.steps)).rounded())
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        up ? onUp() : onDown()
    }
}
