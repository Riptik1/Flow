//
//  KeyboardLayout.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//


import Foundation

struct MKey: Identifiable {
    let id = UUID()
    let top: String
    let label: String
    let units: CGFloat
    let kind: Kind

    enum Kind { case letter, dual, modifier, space, delete, ret, tab, capsLock, fn }

    init(_ top: String = "", _ label: String, u: CGFloat = 1.0, k: Kind = .letter) {
        self.top = top; self.label = label; self.units = u; self.kind = k
    }
}

enum KeyboardLayout {
    static let gap: CGFloat = 5.0

    static let row1: [MKey] = [
        MKey("~", "`", k: .dual), MKey("!", "1", k: .dual), MKey("@", "2", k: .dual), MKey("#", "3", k: .dual),
        MKey("$", "4", k: .dual), MKey("%", "5", k: .dual), MKey("^", "6", k: .dual), MKey("&", "7", k: .dual),
        MKey("*", "8", k: .dual), MKey("(", "9", k: .dual), MKey(")", "0", k: .dual), MKey("–", "-", k: .dual),
        MKey("+", "=", k: .dual), MKey("", "delete", u: 1.5, k: .delete)
    ]
    static let row2: [MKey] = [
        MKey("", "tab", u: 1.5, k: .tab),
        MKey("", "Q"), MKey("", "W"), MKey("", "E"), MKey("", "R"), MKey("", "T"), MKey("", "Y"),
        MKey("", "U"), MKey("", "I"), MKey("", "O"), MKey("", "P"),
        MKey("{", "[", k: .dual), MKey("}", "]", k: .dual), MKey("|", "\\", k: .dual)
    ]
    static let row3: [MKey] = [
        MKey("", "caps lock", u: 1.75, k: .capsLock),
        MKey("", "A"), MKey("", "S"), MKey("", "D"), MKey("", "F"), MKey("", "G"),
        MKey("", "H"), MKey("", "J"), MKey("", "K"), MKey("", "L"),
        MKey(":", ";", k: .dual), MKey("\"", "'", k: .dual), MKey("", "return", u: 1.75, k: .ret)
    ]
    static let row4: [MKey] = [
        MKey("", "shift", u: 2.25, k: .modifier),
        MKey("", "Z"), MKey("", "X"), MKey("", "C"), MKey("", "V"), MKey("", "B"),
        MKey("", "N"), MKey("", "M"), MKey("<", ",", k: .dual), MKey(">", ".", k: .dual), MKey("?", "/", k: .dual),
        MKey("", "shift", u: 2.25, k: .modifier)
    ]

    static let leftBottomModifiers: [MKey] = [
        MKey("", "fn", k: .fn), MKey("", "control", k: .modifier),
        MKey("", "option", k: .modifier), MKey("", "command", u: 1.25, k: .modifier)
    ]
    static let spaceKey = MKey("", "space", u: 5.0, k: .space)
    static let rightBottomModifiers: [MKey] = [
        MKey("", "command", u: 1.25, k: .modifier), MKey("", "option", k: .modifier)
    ]

    static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "g": 5, "h": 4, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "q": 12, "w": 13, "e": 14, "r": 15, "t": 17, "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
        "l": 37, "k": 40, "j": 38, ";": 41, "'": 39, "\\": 42, "n": 45, "m": 46, ",": 43, ".": 47, "/": 44,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        "-": 27, "=": 24, "`": 50, "[": 33, "]": 30,
        "return": 36, "tab": 48, "space": 49, "delete": 51,
        "left": 123, "right": 124, "up": 126, "down": 125
    ]

    static let arrowKeyCodes: [String: Int] = ["left": 123, "right": 124, "up": 126, "down": 125]

    static let typingCharCodes: [Character: (code: Int, shift: Bool)] = [
        "a": (0, false), "b": (11, false), "c": (8, false),
        "d": (2, false), "e": (14, false), "f": (3, false),
        "g": (5, false), "h": (4, false), "i": (34, false),
        "j": (38, false), "k": (40, false), "l": (37, false),
        "m": (46, false), "n": (45, false), "o": (31, false),
        "p": (35, false), "q": (12, false), "r": (15, false),
        "s": (1, false), "t": (17, false), "u": (32, false),
        "v": (9, false), "w": (13, false), "x": (7, false),
        "y": (16, false), "z": (6, false),
        "1": (18, false), "2": (19, false), "3": (20, false),
        "4": (21, false), "5": (23, false), "6": (22, false),
        "7": (26, false), "8": (28, false), "9": (25, false),
        "0": (29, false), " ": (49, false), "\n": (36, false),
        "\t": (48, false), "-": (27, false)
    ]

    static let functionKeyPairs: [(String, Int)] = [
        ("F1", 122), ("F2", 120), ("F3", 99), ("F4", 118), ("F5", 96), ("F6", 97),
        ("F7", 98), ("F8", 100), ("F9", 101), ("F10", 109), ("F11", 103), ("F12", 111)
    ]

    static let emojiList: [String] = [
        "😀", "😂", "🥹", "😍", "🤔", "😅", "😊", "🥰", "😎", "😭", "🤣", "😇", "🤩", "🥳", "😏", "😉", "🙃", "😴", "🤯", "😡",
        "👍", "👎", "👋", "🙏", "💪", "🤝", "🫡", "👀", "🙌", "✌️", "🤞", "🫶", "👏", "🤦", "🤷",
        "❤️", "🔥", "✅", "💯", "⭐", "🎉", "🚀", "💡", "📌", "✨", "🎯", "💎", "🌟", "⚡", "🎊", "🏆", "💫", "🔑", "🎁", "👇"
    ]
}
