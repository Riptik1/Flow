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
    private var lastSwitchedIDs  : [String: UInt64] = [:]
    private var dragResumeTimer  : DispatchWorkItem?
    private let dragResumeWindow : TimeInterval = 1.0

    private let scrollSpeedV  : CGFloat      = 2.2
    private let scrollSpeedH  : CGFloat      = 2.2
    private let magnifyGain   : CGFloat      = 2.4
    private let swipeCooldown : TimeInterval = 0.45

    private let fContinuous   = CGEventField(rawValue: 88)!
    private let fMagnitude    = CGEventField(rawValue: 118)!
    private let fGesturePhase = CGEventField(rawValue: 132)!
    private let fSmartZoom    = CGEventField(rawValue: 137)!
    private let tMagnify      = CGEventType(rawValue: 30)!

    private typealias CGSConnectionID = UInt32
    private typealias CGSSpaceID      = UInt64
    private typealias CGSConnFn       = @convention(c) () -> CGSConnectionID
    private typealias CGSDisplaysFn   = @convention(c) (CGSConnectionID) -> CFArray?
    private typealias CGSSetSpaceFn    = @convention(c) (CGSConnectionID, CFString, CGSSpaceID) -> Void
    private typealias CGSHideSpacesFn  = @convention(c) (CGSConnectionID, CFArray) -> Void

    private lazy var spaceAPI: (conn: CGSConnFn, displays: CGSDisplaysFn, set: CGSSetSpaceFn, hide: CGSHideSpacesFn)? = {
        guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let c = dlsym(h, "CGSMainConnectionID"),
              let d = dlsym(h, "CGSCopyManagedDisplaySpaces"),
              let s = dlsym(h, "CGSManagedDisplaySetCurrentSpace"),
              let hi = dlsym(h, "CGSHideSpaces") else { return nil }
        return (
            unsafeBitCast(c,  to: CGSConnFn.self),
            unsafeBitCast(d,  to: CGSDisplaysFn.self),
            unsafeBitCast(s,  to: CGSSetSpaceFn.self),
            unsafeBitCast(hi, to: CGSHideSpacesFn.self)
        )
    }()

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
        cursor = clamp(CGPoint(x: cursor.x + dx, y: cursor.y + dy))
        CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: cursor, mouseButton: .left)?.post(tap: .cghidEventTap)
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
        if fingers >= 4 {
            fourFingerSwipe(dir)
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

    private func fourFingerSwipe(_ dir: SwipeDirection) {
        let now = Date()
        if let last = lastSwipeAt, now.timeIntervalSince(last) < swipeCooldown { return }
        lastSwipeAt = now

        switch dir {
        case .left:  switchSpaceAllDisplays(forward: true)
        case .right: switchSpaceAllDisplays(forward: false)
        case .up:    openMissionControl()
        case .down:  openAppExpose()
        }
    }

    private func openMissionControl() {
        DispatchQueue.main.async {
            NSWorkspace.shared.open(
                URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            )
        }
    }

    private func openAppExpose() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.apple.expose.front"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func switchSpaceAllDisplays(forward: Bool) {
        guard let api = spaceAPI else { return }
        let conn = api.conn()
        guard let raw = api.displays(conn) as? [[String: Any]] else { return }

        let activeCursorPoint = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first {
            NSMouseInRect(activeCursorPoint, $0.frame, false)
        } ?? NSScreen.main

        for display in raw {
            guard let spaces    = display["Spaces"] as? [[String: Any]],
                  let displayID = display["Display Identifier"] as? String else { continue }

            let screenForDisplay = NSScreen.screens.first { screen -> Bool in
                guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
                let uuid = CGDisplayCreateUUIDFromDisplayID(num).takeRetainedValue()
                let uuidString = CFUUIDCreateString(nil, uuid) as String
                return uuidString == displayID
            }

            let isActiveDisplay: Bool
            if let scr = screenForDisplay {
                isActiveDisplay = (scr == activeScreen)
            } else {
                isActiveDisplay = (displayID == raw.first?["Display Identifier"] as? String)
            }
            guard isActiveDisplay else { continue }

            let ids = spaces.compactMap { $0["id64"] as? UInt64 }
            guard !ids.isEmpty else { continue }

            let currentID: UInt64
            if let tracked = lastSwitchedIDs[displayID], ids.contains(tracked) {
                currentID = tracked
            } else if let currentSpaceDict = display["Current Space"] as? [String: Any],
                      let liveID = currentSpaceDict["id64"] as? UInt64 {
                currentID = liveID
            } else {
                currentID = ids[0]
            }

            guard let currentIdx = ids.firstIndex(of: currentID) else { continue }
            let targetIdx = forward ? currentIdx + 1 : currentIdx - 1
            guard targetIdx >= 0 && targetIdx < ids.count else {
                lastSwitchedIDs[displayID] = currentID
                continue
            }

            let targetID  = ids[targetIdx]
            let hideArray = [currentID as CFNumber] as CFArray
            lastSwitchedIDs[displayID] = targetID
            api.hide(conn, hideArray)
            api.set(conn, displayID as CFString, targetID)
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
        cursor = clamp(CGPoint(x: cursor.x + dx, y: cursor.y + dy))
        CGEvent(mouseEventSource: src, mouseType: .leftMouseDragged, mouseCursorPosition: cursor, mouseButton: .left)?.post(tap: .cghidEventTap)
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
