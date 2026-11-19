//
//  TrackpadService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 24/05/26.
//

#if canImport(AppKit)
import AppKit
import CoreGraphics
import ApplicationServices

final class TrackpadService {
    static let shared = TrackpadService()

    private let src   = CGEventSource(stateID: .hidSystemState)
    private let queue = DispatchQueue(label: "com.flow.trackpad", qos: .userInteractive)

    private var cursor           = CGPoint.zero
    private var lastMove         : Date?
    private var scrollActive     = false
    private var magActive        = false
    private var dragActive       = false
    private var lastSwipeAt      : Date?
    private var dragResumeTimer  : DispatchWorkItem?
    private let dragResumeWindow : TimeInterval = 1.0

    private let scrollSpeedV  : CGFloat      = 2.2
    private let scrollSpeedH  : CGFloat      = 2.2
    private let magnifyGain   : CGFloat      = 2.4
    private let swipeCooldown : TimeInterval = 0.32

    private let fContinuous   = CGEventField(rawValue: 88)!
    private let fMagnitude    = CGEventField(rawValue: 118)!
    private let fGesturePhase = CGEventField(rawValue: 132)!
    private let fSmartZoom    = CGEventField(rawValue: 137)!
    private let tMagnify      = CGEventType(rawValue: 30)!

    private init() { cursor = osCursor() }

    func handle(_ msg: FlowMessage) {
        queue.async { [weak self] in self?.process(msg) }
    }

    private func process(_ msg: FlowMessage) {
        switch msg {
        case .mouseMove(let dx, let dy):              move(CGFloat(dx), CGFloat(dy))
        case .leftClick:                              leftClick()
        case .rightClick:                             rightClick()
        case .doubleClick:                            doubleClick()
        case .scrollBegan:                            scrollBegan()
        case .scroll(let dx, let dy):                 scroll(CGFloat(dx), CGFloat(dy))
        case .scrollEnded:                            scrollEnded()
        case .magnifyBegan:                           magnifyBegan()
        case .magnify(let d):                         doMagnify(CGFloat(d))
        case .magnifyEnded:                           magnifyEnded()
        case .smartZoom:                              smartZoom()
        case .swipe(let dir, let fingers):            swipe(dir, fingers)
        case .clickDragBegin:                         dragBegin()
        case .clickDragMove(let dx, let dy):          dragMove(CGFloat(dx), CGFloat(dy))
        case .clickDragEnd:                           dragEnd()
        case .threeFingerDragBegin:                   dragBegin()
        case .threeFingerDragMove(let dx, let dy):    dragMove(CGFloat(dx), CGFloat(dy))
        case .threeFingerDragEnd:                     dragEnd()
        default: break
        }
    }

    private func osCursor() -> CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x, y: primaryH() - p.y)
    }
    private func primaryH() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 900
    }
    private var cachedScreenRect: CGRect = .null
    private var screenRectAge: CFTimeInterval = 0

    private func screenRect() -> CGRect {
        let now = CACurrentMediaTime()
        if !cachedScreenRect.isNull && now - screenRectAge < 2.0 { return cachedScreenRect }
        let h = primaryH()
        cachedScreenRect = NSScreen.screens.reduce(CGRect.null) { acc, s in
            let r = CGRect(x: s.frame.minX, y: h - s.frame.maxY, width: s.frame.width, height: s.frame.height)
            return acc.isNull ? r : acc.union(r)
        }
        screenRectAge = now
        return cachedScreenRect
    }
    private func clamp(_ p: CGPoint) -> CGPoint {
        let r = screenRect(); guard !r.isNull else { return p }
        return CGPoint(x: min(max(p.x, r.minX), r.maxX - 1), y: min(max(p.y, r.minY), r.maxY - 1))
    }

    private func move(_ dx: CGFloat, _ dy: CGFloat) {
        if let t = lastMove, Date().timeIntervalSince(t) > 2.0 { cursor = osCursor() }
        lastMove = Date()
        let previous = cursor
        cursor = clamp(CGPoint(x: cursor.x + dx, y: cursor.y + dy))
        let e = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: cursor, mouseButton: .left)
        // Apps that read relative motion (hover effects, drawing tools) need the deltas too.
        e?.setIntegerValueField(.mouseEventDeltaX, value: Int64((cursor.x - previous.x).rounded()))
        e?.setIntegerValueField(.mouseEventDeltaY, value: Int64((cursor.y - previous.y).rounded()))
        e?.post(tap: .cghidEventTap)
    }

    private func leftClick() {
        if dragActive { dragEnd() }
        cursor = osCursor()
        mouseEvent(.leftMouseDown, btn: .left, state: 1)
        mouseEvent(.leftMouseUp,   btn: .left, state: 1)
    }

    private func rightClick() {
        if dragActive { dragEnd() }
        cursor = osCursor()
        mouseEvent(.rightMouseDown, btn: .right, state: 1)
        mouseEvent(.rightMouseUp,   btn: .right, state: 1)
    }

    private func doubleClick() {
        if dragActive { dragEnd() }
        cursor = osCursor()
        mouseEvent(.leftMouseDown, btn: .left, state: 1)
        mouseEvent(.leftMouseUp,   btn: .left, state: 1)
        mouseEvent(.leftMouseDown, btn: .left, state: 2)
        mouseEvent(.leftMouseUp,   btn: .left, state: 2)
    }

    private func mouseEvent(_ type: CGEventType, btn: CGMouseButton, state: Int64) {
        let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: cursor, mouseButton: btn)
        e?.setIntegerValueField(.mouseEventClickState, value: state)
        e?.post(tap: .cghidEventTap)
    }

    private func scrollBegan() {
        if scrollActive {
            postScroll(0, 0, ph: 4)
            postScroll(0, 0, ph: 0, momentum: 4)
        }
        scrollActive = true
        postScroll(0, 0, ph: 1)
    }

    private func scroll(_ dx: CGFloat, _ dy: CGFloat) {
        if !scrollActive { scrollBegan() }
        let wheel1 = Int32((dy * scrollSpeedV).rounded())
        let wheel2 = Int32((dx * scrollSpeedH).rounded())
        if wheel1 == 0 && wheel2 == 0 { return }
        postScroll(wheel1, wheel2, ph: 2)
    }

    private func scrollEnded() {
        guard scrollActive else { return }
        scrollActive = false
        postScroll(0, 0, ph: 4)
    }

    private func postScroll(_ w1: Int32, _ w2: Int32, ph: Int64, momentum: Int64 = 0) {
        let e = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 2, wheel1: w1, wheel2: w2, wheel3: 0)
        e?.setIntegerValueField(.scrollWheelEventScrollPhase, value: ph)
        if momentum != 0 { e?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum) }
        e?.setIntegerValueField(fContinuous, value: 1)
        e?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e?.post(tap: .cghidEventTap)
    }

    private func magnifyBegan() {
        if magActive { postMag(0, ph: 4) }
        magActive = true
        postMag(0, ph: 1)
    }
    private func doMagnify(_ d: CGFloat) {
        if !magActive { magnifyBegan() }
        postMag(d * magnifyGain, ph: 2)
    }
    private func magnifyEnded() {
        guard magActive else { return }
        magActive = false
        postMag(0, ph: 4)
    }
    private func postMag(_ delta: CGFloat, ph: Int64) {
        guard let e = CGEvent(source: src) else { return }
        e.type = tMagnify
        e.setDoubleValueField(fMagnitude, value: Double(delta))
        e.setIntegerValueField(fGesturePhase, value: ph)
        e.post(tap: .cghidEventTap)
    }

    private func smartZoom() {
        guard let e = CGEvent(source: src) else { return }
        e.type = tMagnify
        e.setDoubleValueField(fMagnitude, value: 0)
        e.setIntegerValueField(fGesturePhase, value: 8)
        e.setIntegerValueField(fSmartZoom,    value: 1)
        e.post(tap: .cghidEventTap)
    }

    private func swipe(_ dir: SwipeDirection, _ fingers: Int) {
        if fingers >= 3 {
            navigationSwipe(dir)
        } else if fingers == 2 {
            twoFingerSwipe(dir)
        } else {
            switch dir {
            case .up:    key(126, flags: .maskControl)
            case .down:  key(125, flags: .maskControl)
            case .left:  key(123, flags: .maskControl)
            case .right: key(124, flags: .maskControl)
            }
        }
    }

    private func twoFingerSwipe(_ dir: SwipeDirection) {
        switch dir {
        case .right: key(33, flags: .maskCommand)
        case .left:  key(30, flags: .maskCommand)
        case .up:    break
        case .down:  break
        }
    }

    /// 3- or 4-finger swipe. Uses the same keyboard shortcuts macOS binds to those gestures
    /// (Control + arrows), so the system plays its normal smooth animation.
    private func navigationSwipe(_ dir: SwipeDirection) {
        let now = Date()
        if let last = lastSwipeAt, now.timeIntervalSince(last) < swipeCooldown { return }
        lastSwipeAt = now
        let flags: CGEventFlags = [.maskControl, .maskSecondaryFn]
        switch dir {
        case .left:  key(124, flags: flags)   // swipe left  -> next Space (to the right)
        case .right: key(123, flags: flags)   // swipe right -> previous Space
        case .up:    key(126, flags: flags)   // Mission Control
        case .down:  key(125, flags: flags)   // App Exposé
        }
    }

    private func key(_ code: CGKeyCode, flags: CGEventFlags) {
        let d = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        d?.flags = flags
        d?.post(tap: .cghidEventTap)
        let u = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        u?.flags = flags
        u?.post(tap: .cghidEventTap)
    }

    private func dragBegin() {
        if dragActive { return }
        if let pending = dragResumeTimer {
            pending.cancel()
            dragResumeTimer = nil
            dragActive = true
            return
        }
        dragActive = true
        cursor = osCursor()
        let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: cursor, mouseButton: .left)
        e?.setIntegerValueField(.mouseEventClickState, value: 1)
        e?.post(tap: .cghidEventTap)
    }
    private func dragMove(_ dx: CGFloat, _ dy: CGFloat) {
        guard dragActive else { return }
        let previous = cursor
        cursor = clamp(CGPoint(x: cursor.x + dx, y: cursor.y + dy))
        let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseDragged, mouseCursorPosition: cursor, mouseButton: .left)
        e?.setIntegerValueField(.mouseEventDeltaX, value: Int64((cursor.x - previous.x).rounded()))
        e?.setIntegerValueField(.mouseEventDeltaY, value: Int64((cursor.y - previous.y).rounded()))
        e?.post(tap: .cghidEventTap)
    }
    private func dragEnd() {
        guard dragActive else { return }
        dragActive = false
        dragResumeTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let e = CGEvent(mouseEventSource: self.src, mouseType: .leftMouseUp, mouseCursorPosition: self.cursor, mouseButton: .left)
            e?.setIntegerValueField(.mouseEventClickState, value: 1)
            e?.post(tap: .cghidEventTap)
            self.dragResumeTimer = nil
        }
        dragResumeTimer = item
        queue.asyncAfter(deadline: .now() + dragResumeWindow, execute: item)
    }
}
#endif
