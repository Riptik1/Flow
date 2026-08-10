import Combine
import SwiftUI

final class MacUnlockViewModel: ObservableObject {
    @Published var charCount: Int = 0
    @Published var shakeOffset: CGFloat = 0
    @Published var showError: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var isAwake: Bool = false
    @Published var fieldFocused: Bool = false

    private static let maskShift: Int = 0x20000

    private static let keyMap: [Character: Int] = [
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,  "z": 6,  "x": 7,
        "c": 8,  "v": 9,  "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, " ": 49, "`": 50
    ]

    private static let shiftMap: [Character: Int] = [
        "A": 0,  "S": 1,  "D": 2,  "F": 3,  "H": 4,  "G": 5,  "Z": 6,  "X": 7,
        "C": 8,  "V": 9,  "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15,
        "Y": 16, "T": 17, "!": 18, "@": 19, "#": 20, "$": 21, "^": 22,
        "%": 23, "+": 24, "(": 25, "&": 26, "_": 27, "*": 28, ")": 29,
        "}": 30, "O": 31, "U": 32, "{": 33, "I": 34, "P": 35, "L": 37,
        "J": 38, "\"": 39, "K": 40, ":": 41, "|": 42, "<": 43, "?": 44,
        "N": 45, "M": 46, ">": 47, "~": 50
    ]

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var pendingTimeout: DispatchWorkItem?

    init(connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.connectionService = connectionService
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.handle(message) }
            .store(in: &cancellables)
    }

    func resetState() {
        charCount = 0
        showError = false
        isSubmitting = false
        isAwake = false
        fieldFocused = false
        pendingTimeout?.cancel()
        pendingTimeout = nil
    }

    func wake() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        connectionService.send(.wakeMac)
        withAnimation { isAwake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.fieldFocused = true }
    }

    func appendCharacter(_ char: Character) {
        guard !isSubmitting else { return }
        charCount += 1
        if let code = Self.keyMap[char] {
            connectionService.send(.keyPress(keyCode: code, modifiers: 0))
        } else if let code = Self.shiftMap[char] {
            connectionService.send(.keyPress(keyCode: code, modifiers: Self.maskShift))
        }
    }

    func backspace() {
        guard !isSubmitting, charCount > 0 else { return }
        charCount -= 1
        connectionService.send(.keyPress(keyCode: 51, modifiers: 0))
    }

    func clearAll() {
        let n = charCount
        charCount = 0
        for _ in 0..<n { connectionService.send(.keyPress(keyCode: 51, modifiers: 0)) }
    }

    func submitPassword() {
        guard charCount > 0, !isSubmitting else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSubmitting = true
        showError = false
        connectionService.send(.keyPress(keyCode: 36, modifiers: 0))

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isSubmitting = false
            self.showError = true
            self.charCount = 0
            self.triggerShake()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { self.showError = false }
            }
        }
        pendingTimeout = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: task)
    }

    private func triggerShake() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        let sequence: [(CGFloat, Double)] = [
            (-12, 0.00), (12, 0.07), (-10, 0.14),
            (10, 0.21), (-6, 0.28), (6, 0.35), (0, 0.42)
        ]
        for (offset, delay) in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                withAnimation(.easeInOut(duration: 0.06)) { self?.shakeOffset = offset }
            }
        }
    }

    private func handle(_ message: FlowMessage) {
        guard case .macLockedState(let locked) = message, !locked, isSubmitting else { return }
        pendingTimeout?.cancel()
        pendingTimeout = nil
        isSubmitting = false
        showError = false
    }
}
