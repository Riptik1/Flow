//
//  MirrorInputView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Network
import SwiftUI
import UIKit

final class MirrorInputView: UIView, UIGestureRecognizerDelegate {
    var onTap: ((CGPoint, CGSize) -> Void)?
    var onDoubleTap: ((CGPoint, CGSize) -> Void)?
    var onRightClick: ((CGPoint, CGSize) -> Void)?
    var onDragBegan: ((CGPoint, CGSize) -> Void)?
    var onDragMoved: ((CGPoint, CGSize) -> Void)?
    var onDragEnded: ((CGPoint, CGSize) -> Void)?
    var onSelectionBegan: ((CGPoint, CGSize) -> Void)?
    var onSelectionMoved: ((CGPoint, CGSize) -> Void)?
    var onSelectionEnded: ((CGPoint, CGSize) -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?
    var onPinchChanged: ((CGFloat, UnitPoint) -> Void)?
    var onPinchEnded: (() -> Void)?
    var onKey: ((UIKeyboardHIDUsage, UIKeyModifierFlags, Bool) -> Void)?
    var onText: ((String) -> Void)?

    var showKeyboard: Bool = false {
        didSet {
            guard oldValue != showKeyboard else { return }
            if showKeyboard { becomeFirstResponder() }
            else { resignFirstResponder() }
        }
    }

    private var tapGesture: UITapGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    private var twoFingerTapGesture: UITapGestureRecognizer!
    private var twoFingerDoubleTapGesture: UITapGestureRecognizer!
    private var dragGesture: UILongPressGestureRecognizer!
    private var scrollGesture: UIPanGestureRecognizer!
    private var selectionGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var accumulatedPinchScale: CGFloat = 1.0
    private var pinchEngaged = false
    private var _inputText = ""
    private var isDragging = false
    private var isSelecting = false

    private enum TwoFingerMode { case undetermined, pan, pinch }
    private var twoFingerMode: TwoFingerMode = .undetermined
    private let pinchEngageThreshold: CGFloat = 0.06
    private let panEngageThreshold: CGFloat = 10

    override var canBecomeFirstResponder: Bool { true }
    override var canResignFirstResponder: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        setupGestures()
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    private func setupGestures() {
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapSingle))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        doubleTapGesture.delegate = self
        addGestureRecognizer(doubleTapGesture)

        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.delegate = self
        tapGesture.require(toFail: doubleTapGesture)
        addGestureRecognizer(tapGesture)

        twoFingerTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap))
        twoFingerTapGesture.numberOfTapsRequired = 1
        twoFingerTapGesture.numberOfTouchesRequired = 2
        twoFingerTapGesture.delegate = self
        addGestureRecognizer(twoFingerTapGesture)

        twoFingerDoubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerDoubleTap))
        twoFingerDoubleTapGesture.numberOfTapsRequired = 2
        twoFingerDoubleTapGesture.numberOfTouchesRequired = 2
        twoFingerDoubleTapGesture.delegate = self
        addGestureRecognizer(twoFingerDoubleTapGesture)

        dragGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag))
        dragGesture.minimumPressDuration = 0.12
        dragGesture.numberOfTouchesRequired = 1
        dragGesture.allowableMovement = .greatestFiniteMagnitude
        dragGesture.delegate = self
        addGestureRecognizer(dragGesture)

        scrollGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScroll))
        scrollGesture.minimumNumberOfTouches = 2
        scrollGesture.maximumNumberOfTouches = 2
        scrollGesture.delegate = self
        addGestureRecognizer(scrollGesture)

        selectionGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSelection))
        selectionGesture.minimumNumberOfTouches = 3
        selectionGesture.maximumNumberOfTouches = 3
        selectionGesture.delegate = self
        addGestureRecognizer(selectionGesture)

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)

        tapGesture.require(toFail: dragGesture)
        twoFingerTapGesture.require(toFail: twoFingerDoubleTapGesture)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if event?.allTouches?.count == 2 {
            twoFingerMode = .undetermined
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        let remaining = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 0
        if remaining < 2 {
            twoFingerMode = .undetermined
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        let remaining = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 0
        if remaining < 2 {
            twoFingerMode = .undetermined
        }
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        if g is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer { return true }
        if (g == scrollGesture && other == twoFingerTapGesture) || (g == twoFingerTapGesture && other == scrollGesture) { return true }
        if (g == scrollGesture && other == twoFingerDoubleTapGesture) || (g == twoFingerDoubleTapGesture && other == scrollGesture) { return true }
        return false
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { true }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard !isDragging, !isSelecting else { return }
        onTap?(g.location(in: self), bounds.size)
    }

    @objc private func handleDoubleTapSingle(_ g: UITapGestureRecognizer) {
        onDoubleTap?(g.location(in: self), bounds.size)
    }

    @objc private func handleTwoFingerTap(_ g: UITapGestureRecognizer) {
        onRightClick?(g.location(in: self), bounds.size)
    }

    @objc private func handleTwoFingerDoubleTap(_ g: UITapGestureRecognizer) {
        onDoubleTap?(g.location(in: self), bounds.size)
    }

    @objc private func handleDrag(_ g: UILongPressGestureRecognizer) {
        let pt = g.location(in: self)
        switch g.state {
        case .began:
            isDragging = true
            onDragBegan?(pt, bounds.size)
        case .changed:
            onDragMoved?(pt, bounds.size)
        case .ended, .cancelled, .failed:
            if isDragging { onDragEnded?(pt, bounds.size) }
            isDragging = false
        default: break
        }
    }

    @objc private func handleScroll(_ g: UIPanGestureRecognizer) {
        guard g.numberOfTouches == 2, g.state == .changed else { return }
        if twoFingerMode == .pinch {
            g.setTranslation(.zero, in: self)
            return
        }
        let t = g.translation(in: self)
        if twoFingerMode == .undetermined {
            guard hypot(t.x, t.y) > panEngageThreshold else { return }
            twoFingerMode = .pan
        }
        guard twoFingerMode == .pan else { return }
        g.setTranslation(.zero, in: self)
        onScroll?(t.x, t.y)
    }

    @objc private func handleSelection(_ g: UIPanGestureRecognizer) {
        let pt = g.location(in: self)
        switch g.state {
        case .began:
            isSelecting = true
            onSelectionBegan?(pt, bounds.size)
        case .changed:
            onSelectionMoved?(pt, bounds.size)
        case .ended, .cancelled, .failed:
            if isSelecting { onSelectionEnded?(pt, bounds.size) }
            isSelecting = false
        default: break
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard let view = g.view else { return }
        let anchor = UnitPoint(
            x: g.location(in: view).x / max(view.bounds.width, 1),
            y: g.location(in: view).y / max(view.bounds.height, 1)
        )
        switch g.state {
        case .began:
            accumulatedPinchScale = g.scale
            pinchEngaged = false
        case .changed:
            if twoFingerMode == .pan {
                accumulatedPinchScale = g.scale
                return
            }
            if twoFingerMode == .undetermined {
                guard abs(g.scale - 1.0) > pinchEngageThreshold else { return }
                twoFingerMode = .pinch
            }
            guard twoFingerMode == .pinch else { return }
            pinchEngaged = true
            let delta = g.scale / accumulatedPinchScale
            accumulatedPinchScale = g.scale
            onPinchChanged?(delta, anchor)
        case .ended, .cancelled:
            if pinchEngaged { onPinchEnded?() }
            pinchEngaged = false
        default: break
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { onKey?(key.keyCode, key.modifierFlags, true) } }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { onKey?(key.keyCode, key.modifierFlags, false) } }
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { onKey?(key.keyCode, key.modifierFlags, false) } }
    }
}

extension MirrorInputView: UIKeyInput {
    var hasText: Bool { !_inputText.isEmpty }

    func insertText(_ text: String) {
        _inputText += text
        onText?(text)
    }

    func deleteBackward() {
        if !_inputText.isEmpty { _inputText.removeLast() }
        onKey?(UIKeyboardHIDUsage(rawValue: 0x2A)!, [], true)
        onKey?(UIKeyboardHIDUsage(rawValue: 0x2A)!, [], false)
    }
}

struct MirrorControlLayer: UIViewRepresentable {
    let containerSize: CGSize
    let captureAspect: CGFloat
    let showKeyboard: Bool
    let onTap: (CGPoint) -> Void
    let onDoubleTap: (CGPoint) -> Void
    let onRightClick: (CGPoint) -> Void
    let onDragBegan: (CGPoint) -> Void
    let onDragMoved: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onSelectionBegan: (CGPoint) -> Void
    let onSelectionMoved: (CGPoint) -> Void
    let onSelectionEnded: (CGPoint) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    let onPinchChanged: (CGFloat, UnitPoint) -> Void
    let onPinchEnded: () -> Void
    let onKey: (UIKeyboardHIDUsage, UIKeyModifierFlags, Bool) -> Void
    let onText: (String) -> Void

    func makeUIView(context: Context) -> MirrorInputView {
        let v = MirrorInputView()
        context.coordinator.configure(v)
        return v
    }

    func updateUIView(_ v: MirrorInputView, context: Context) {
        context.coordinator.parent = self
        if v.showKeyboard != showKeyboard {
            v.showKeyboard = showKeyboard
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator {
        var parent: MirrorControlLayer
        init(parent: MirrorControlLayer) { self.parent = parent }

        func configure(_ v: MirrorInputView) {
            v.onTap          = { [weak self] pt, _ in self?.parent.onTap(pt) }
            v.onDoubleTap    = { [weak self] pt, _ in self?.parent.onDoubleTap(pt) }
            v.onRightClick   = { [weak self] pt, _ in self?.parent.onRightClick(pt) }
            v.onDragBegan    = { [weak self] pt, _ in self?.parent.onDragBegan(pt) }
            v.onDragMoved    = { [weak self] pt, _ in self?.parent.onDragMoved(pt) }
            v.onDragEnded    = { [weak self] pt, _ in self?.parent.onDragEnded(pt) }
            v.onSelectionBegan = { [weak self] pt, _ in self?.parent.onSelectionBegan(pt) }
            v.onSelectionMoved = { [weak self] pt, _ in self?.parent.onSelectionMoved(pt) }
            v.onSelectionEnded = { [weak self] pt, _ in self?.parent.onSelectionEnded(pt) }
            v.onScroll       = { [weak self] dx, dy in self?.parent.onScroll(dx, dy) }
            v.onPinchChanged = { [weak self] d, a in self?.parent.onPinchChanged(d, a) }
            v.onPinchEnded   = { [weak self] in self?.parent.onPinchEnded() }
            v.onKey          = { [weak self] c, m, p in self?.parent.onKey(c, m, p) }
            v.onText         = { [weak self] t in self?.parent.onText(t) }
        }
    }
}
