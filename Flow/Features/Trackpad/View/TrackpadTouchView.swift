//
//  TrackpadHaptics.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//


import SwiftUI
import UIKit

final class TrackpadHaptics {
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft  = UIImpactFeedbackGenerator(style: .soft)
    init() { rigid.prepare(); soft.prepare() }
    func tap()   { rigid.impactOccurred(intensity: 0.9); rigid.prepare() }
    func drag()  { soft.impactOccurred(intensity: 0.4);  soft.prepare()  }
    func swipe() { rigid.impactOccurred(intensity: 0.7); rigid.prepare() }
}

struct TrackpadArea: UIViewRepresentable {
    let onTap: () -> Void
    func makeUIView(context: Context) -> TrackpadTouchView {
        let v = TrackpadTouchView(); v.onTap = onTap; return v
    }
    func updateUIView(_ v: TrackpadTouchView, context: Context) { v.onTap = onTap }
}

final class WinRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ ts: Set<UITouch>, with e: UIEvent)     { state = state == .possible ? .began : .changed }
    override func touchesMoved(_ ts: Set<UITouch>, with e: UIEvent)     { state = .changed   }
    override func touchesEnded(_ ts: Set<UITouch>, with e: UIEvent)     { state = .ended     }
    override func touchesCancelled(_ ts: Set<UITouch>, with e: UIEvent) { state = .cancelled }
}

final class TrackpadTouchView: UIView, UIGestureRecognizerDelegate {
    var onTap: (() -> Void)?

    private let haptics = TrackpadHaptics()
    private var cm: ConnectionManager { .shared }

    private let settleWindow:       TimeInterval = 0.05
    private let tapSlop:            CGFloat      = 14
    private let tapMaxDuration:     TimeInterval = 0.45
    private let longPressDelay:     TimeInterval = 0.40
    private let scrollStart:        CGFloat      = 2.0
    private let pinchStart:         CGFloat      = 9.0
    private let pinchDominance:     CGFloat      = 0.9
    private let swipeTrigger:       CGFloat      = 22
    private let multiTapCooldown:   TimeInterval = 0.65
    private let rightClickMinDur:   TimeInterval = 0.05

    private struct TR {
        let id: ObjectIdentifier
        var current: CGPoint
        let start:   CGPoint
    }

    private enum Phase { case settling, oneFinger, twoFinger, multiFinger, dead }
    private enum TwoMode { case undecided, scroll, pinch, swipe }

    private var map = [ObjectIdentifier: TR]()
    private var n: Int { map.count }

    private var phase       = Phase.dead
    private var peakFingers = 0

    private var gestureStart: Date?
    private var maxMove: CGFloat = 0

    private var settleTimer: Timer?
    private var lpTimer: Timer?

    private var twoMode  = TwoMode.undecided
    private var scrollOn = false
    private var pinchOn  = false
    private var pinchGap: CGFloat = 0
    private var startGap: CGFloat = 0

    private var dragging  = false
    private var threeDrag = false

    private var multiAccum = CGPoint.zero
    private var swipeDone      = false
    private var twoSwipeDone   = false
    private var twoAccum       = CGPoint.zero
    private var scrollVelX: CGFloat = 0
    private var scrollVelY: CGFloat = 0

    private var lastTapAt: Date?
    private var multiGestureEndedAt: Date?

    private var lastReported = [ObjectIdentifier: CGPoint]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        let gr = WinRecognizer()
        gr.cancelsTouchesInView = false
        gr.delaysTouchesBegan   = false
        gr.delegate = self
        addGestureRecognizer(gr)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        var v: UIView? = superview
        while let cur = v {
            cur.gestureRecognizers?.forEach { $0.cancelsTouchesInView = false; $0.delaysTouchesBegan = false }
            v = cur.superview
        }
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRequireFailureOf o: UIGestureRecognizer) -> Bool { false }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy o: UIGestureRecognizer) -> Bool { false }
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { true }

    override func touchesBegan(_ ts: Set<UITouch>, with event: UIEvent?) {
        reconcile(event)
        guard cm.state == .connected else { return }

        if map.isEmpty { fullReset() }

        for t in ts {
            let id = ObjectIdentifier(t)
            let p  = t.location(in: self)
            map[id] = TR(id: id, current: p, start: p)
            lastReported[id] = p
        }
        peakFingers = max(peakFingers, n)

        enterSettling()
    }

    override func touchesMoved(_ ts: Set<UITouch>, with event: UIEvent?) {
        reconcile(event)
        guard cm.state == .connected else { return }

        for t in ts {
            let id = ObjectIdentifier(t)
            guard var rec = map[id] else { continue }
            rec.current = t.location(in: self)
            map[id] = rec
            maxMove = max(maxMove, gap(rec.current, rec.start))
        }

        switch phase {
        case .oneFinger:   handleOneFingerMove(ts, event)
        case .twoFinger:   handleTwoFingerMove(ts, event)
        case .multiFinger: handleMultiFingerMove(ts, event)
        case .settling:
            if peakFingers >= 2 && maxMove > scrollStart * 1.5 {
                settleTimer?.invalidate()
                commitPhase()
                switch phase {
                case .twoFinger:   handleTwoFingerMove(ts, event)
                case .multiFinger: handleMultiFingerMove(ts, event)
                default: break
                }
            }
        case .dead: break
        }
    }

    override func touchesEnded(_ ts: Set<UITouch>, with event: UIEvent?) {
        guard cm.state == .connected else { reconcile(event); return }

        let priorPeak = peakFingers
        let committed = phase

        for t in ts {
            let id = ObjectIdentifier(t)
            if let _ = map[id] { map.removeValue(forKey: id) }
            lastReported.removeValue(forKey: id)
        }
        reconcile(event)

        if map.isEmpty {
            finishGesture(priorPeak: priorPeak, committed: committed)
            fullReset()
        }
    }

    override func touchesCancelled(_ ts: Set<UITouch>, with event: UIEvent?) {
        for t in ts {
            map.removeValue(forKey: ObjectIdentifier(t))
            lastReported.removeValue(forKey: ObjectIdentifier(t))
        }
        reconcile(event)
        teardown()
        if peakFingers >= 3 { multiGestureEndedAt = Date() }
        fullReset()
    }

    private func reconcile(_ event: UIEvent?) {
        guard let all = event?.allTouches else { return }
        var alive = Set<ObjectIdentifier>()
        for t in all {
            switch t.phase {
            case .began, .moved, .stationary:
                alive.insert(ObjectIdentifier(t))
            default:
                break
            }
        }
        for key in map.keys where !alive.contains(key) {
            map.removeValue(forKey: key)
            lastReported.removeValue(forKey: key)
        }
    }

    private func enterSettling() {
        if gestureStart == nil { gestureStart = Date(); maxMove = 0 }
        phase = .settling
        settleTimer?.invalidate()
        settleTimer = Timer.scheduledTimer(withTimeInterval: settleWindow, repeats: false) { [weak self] _ in
            self?.commitPhase()
        }
        if peakFingers == 1 {
            armLongPress()
        } else {
            lpTimer?.invalidate(); lpTimer = nil
        }
    }

    private func commitPhase() {
        guard phase == .settling else { return }
        switch peakFingers {
        case 0:  phase = .dead
        case 1:  phase = .oneFinger
        case 2:  phase = .twoFinger;   beginTwoFinger()
        default: phase = .multiFinger; beginMulti()
        }
    }

    private func armLongPress() {
        lpTimer?.invalidate()
        lpTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in
            guard let s = self else { return }
            guard s.peakFingers == 1, s.n == 1, !s.dragging, s.maxMove < s.tapSlop else { return }
            s.dragging = true
            s.phase = .oneFinger
            s.haptics.drag()
            s.cm.send(.clickDragBegin)
        }
    }

    private func handleOneFingerMove(_ ts: Set<UITouch>, _ event: UIEvent?) {
        guard let t = ts.first, let rec = map[ObjectIdentifier(t)] else { return }
        let pool = event?.coalescedTouches(for: t) ?? [t]
        var dx: CGFloat = 0; var dy: CGFloat = 0
        var acc = lastReported[rec.id] ?? rec.start
        for ct in pool {
            let p = ct.location(in: self)
            dx += p.x - acc.x; dy += p.y - acc.y; acc = p
        }
        lastReported[rec.id] = acc
        if maxMove > tapSlop { lpTimer?.invalidate(); lpTimer = nil }
        guard dx != 0 || dy != 0 else { return }
        let (ax, ay) = accel(dx, dy)
        if dragging { cm.sendUnreliable(.clickDragMove(dx: Float(ax), dy: Float(ay))) }
        else        { cm.sendUnreliable(.mouseMove(dx: Float(ax), dy: Float(ay))) }
    }

    private func beginTwoFinger() {
        twoMode = .undecided; scrollOn = false; pinchOn = false
        twoSwipeDone = false; twoAccum = .zero
        scrollVelX = 0; scrollVelY = 0
        if map.count >= 2 {
            let mv = map.values
            let v0 = mv[mv.startIndex], v1 = mv[mv.index(after: mv.startIndex)]
            startGap = gap(v0.current, v1.current)
            pinchGap = startGap
        }
        for (k, r) in map { lastReported[k] = r.current }
    }

    private func handleTwoFingerMove(_ ts: Set<UITouch>, _ event: UIEvent?) {
        guard map.count >= 2 else { return }

        var cdx: CGFloat = 0; var cdy: CGFloat = 0; var mc: CGFloat = 0
        for t in ts {
            let id = ObjectIdentifier(t)
            guard let rec = map[id] else { continue }
            let pool = event?.coalescedTouches(for: t) ?? [t]
            var acc = lastReported[id] ?? rec.current
            for ct in pool {
                let c = ct.location(in: self)
                cdx += c.x - acc.x; cdy += c.y - acc.y; acc = c
            }
            lastReported[id] = acc
            mc += 1
        }
        if mc > 0 { cdx /= mc; cdy /= mc }

        let mv = map.values
        let v0 = mv[mv.startIndex], v1 = mv[mv.index(after: mv.startIndex)]
        let nd = gap(v0.current, v1.current)
        let dd = nd - pinchGap
        pinchGap = nd

        let gapDrift = abs(nd - startGap)
        _ = hypot(cdx, cdy)
        let accumulatedTranslation = max(0.001, maxMove)

        if twoMode == .undecided {
            let pinchScore = gapDrift
            let scrollScore = accumulatedTranslation
            if pinchScore > pinchStart && pinchScore > scrollScore * pinchDominance {
                twoMode = .pinch
                pinchOn = true
                cm.sendUnreliable(.magnifyBegan)
            } else if scrollScore > scrollStart {
                twoMode = .scroll
                scrollOn = true
                cm.sendUnreliable(.scrollBegan)
            }
        }

        switch twoMode {
        case .scroll:
            twoAccum.x += cdx; twoAccum.y += cdy
            if !twoSwipeDone && abs(twoAccum.x) > 80 && abs(twoAccum.x) > abs(twoAccum.y) * 2.5 {
                twoSwipeDone = true
                twoMode = .swipe
                if scrollOn { scrollOn = false; cm.sendUnreliable(.scrollEnded) }
                let dir: SwipeDirection = twoAccum.x > 0 ? .right : .left
                haptics.swipe()
                cm.send(.swipe(direction: dir, fingers: 2))
            } else if cdx != 0 || cdy != 0 {
                scrollVelX = scrollVelX * 0.6 + cdx * 0.4
                scrollVelY = scrollVelY * 0.6 + cdy * 0.4
                cm.sendUnreliable(.scroll(dx: Float(scrollVelX), dy: Float(scrollVelY)))
            }
        case .swipe:
            break
        case .pinch:
            if abs(dd) > 0.05 {
                cm.sendUnreliable(.magnify(delta: Float(dd) * 0.012))
            }
        case .undecided:
            break
        }
    }

    private func beginMulti() {
        multiAccum = .zero; swipeDone = false; threeDrag = false
        for (k, r) in map { lastReported[k] = r.current }

        if peakFingers == 3 {
            threeDrag = true
            haptics.drag()
            cm.send(.threeFingerDragBegin)
        }
    }

    private func handleMultiFingerMove(_ ts: Set<UITouch>, _ event: UIEvent?) {
        var dx: CGFloat = 0; var dy: CGFloat = 0; var mc: CGFloat = 0
        for t in ts {
            let id = ObjectIdentifier(t)
            guard let rec = map[id] else { continue }
            let pool = event?.coalescedTouches(for: t) ?? [t]
            var acc = lastReported[id] ?? rec.current
            for ct in pool {
                let c = ct.location(in: self)
                dx += c.x - acc.x; dy += c.y - acc.y; acc = c
            }
            lastReported[id] = acc
            mc += 1
        }
        if mc == 0 { return }
        let avgDx = dx / mc; let avgDy = dy / mc
        multiAccum.x += avgDx; multiAccum.y += avgDy

        if peakFingers == 3 {
            if threeDrag, avgDx != 0 || avgDy != 0 {
                let (ax, ay) = accel(avgDx, avgDy)
                cm.sendUnreliable(.threeFingerDragMove(dx: Float(ax), dy: Float(ay)))
            }
            return
        }

        if !swipeDone && (abs(multiAccum.x) >= swipeTrigger || abs(multiAccum.y) >= swipeTrigger) {
            swipeDone = true
            let dir: SwipeDirection = abs(multiAccum.x) >= abs(multiAccum.y)
                ? (multiAccum.x > 0 ? .right : .left)
                : (multiAccum.y > 0 ? .down  : .up)
            haptics.swipe()
            cm.send(.swipe(direction: dir, fingers: min(peakFingers, 4)))
            multiGestureEndedAt = Date()
        }
    }

    private func finishGesture(priorPeak: Int, committed: Phase) {
        let wasDragging   = dragging
        let wasThreeDrag  = threeDrag

        if dragging  { dragging = false;  cm.send(.clickDragEnd) }
        if threeDrag { threeDrag = false; cm.send(.threeFingerDragEnd) }
        if scrollOn  { scrollOn = false;  cm.sendUnreliable(.scrollEnded) }
        if pinchOn   { pinchOn  = false;  cm.sendUnreliable(.magnifyEnded) }

        let duration = gestureStart.map { Date().timeIntervalSince($0) } ?? 1
        let wasTap   = maxMove < tapSlop && duration < tapMaxDuration

        if priorPeak >= 3 {
            multiGestureEndedAt = Date()
            return
        }

        if let last = multiGestureEndedAt, Date().timeIntervalSince(last) < multiTapCooldown {
            return
        }

        if priorPeak == 1 && wasTap && committed != .dead && !wasDragging && !wasThreeDrag {
            let now = Date()
            if let last = lastTapAt, now.timeIntervalSince(last) < 0.32 {
                haptics.tap(); cm.send(.doubleClick); lastTapAt = nil
            } else {
                haptics.tap(); cm.send(.leftClick); lastTapAt = now
            }
            onTap?()
            return
        }

        if priorPeak == 2
            && wasTap
            && committed == .twoFinger
            && twoMode == .undecided
            && duration >= rightClickMinDur {
            haptics.tap(); cm.send(.rightClick)
            return
        }
    }

    private func teardown() {
        if dragging  { dragging = false;  cm.send(.clickDragEnd) }
        if threeDrag { threeDrag = false; cm.send(.threeFingerDragEnd) }
        if scrollOn  { scrollOn = false;  cm.sendUnreliable(.scrollEnded) }
        if pinchOn   { pinchOn  = false;  cm.sendUnreliable(.magnifyEnded) }
    }

    private func fullReset() {
        settleTimer?.invalidate(); settleTimer = nil
        lpTimer?.invalidate(); lpTimer = nil
        phase = .dead
        peakFingers = 0
        gestureStart = nil
        maxMove = 0
        twoMode = .undecided; twoSwipeDone = false; twoAccum = .zero
        scrollVelX = 0; scrollVelY = 0
        scrollOn = false; pinchOn = false
        pinchGap = 0; startGap = 0
        dragging = false; threeDrag = false
        multiAccum = .zero; swipeDone = false
        lastReported.removeAll(keepingCapacity: false)
        map.removeAll(keepingCapacity: false)
    }

    private func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    private func accel(_ dx: CGFloat, _ dy: CGFloat) -> (CGFloat, CGFloat) {
        let m = hypot(dx, dy); guard m > 0 else { return (0, 0) }
        let factor = min(4.0, 1.5 + m * 0.072)
        return (dx * factor, dy * factor)
    }
}
