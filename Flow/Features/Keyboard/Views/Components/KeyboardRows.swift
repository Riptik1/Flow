import SwiftUI

struct KeyboardRow: View {
    let keys: [MKey]; let availW: CGFloat; let keyH: CGFloat
    let capsOn: Bool; let fs: CGFloat; let activeKeys: [String: Bool]
    let onPress: (MKey) -> Void
    var body: some View {
        let units = keys.reduce(CGFloat(0)) { $0 + $1.units }
        let unitW = max(1.0, (availW - KeyboardLayout.gap * CGFloat(keys.count - 1)) / units)
        HStack(spacing: KeyboardLayout.gap) {
            ForEach(keys) { k in
                KeyBtn(key: k, width: max(1.0, unitW * k.units), height: max(1.0, keyH),
                       capsOn: capsOn, active: activeKeys[k.label.lowercased()] ?? false,
                       fs: fs, onPress: onPress)
            }
        }
    }
}

struct BottomKeyRow: View {
    let availW: CGFloat; let keyH: CGFloat; let capsOn: Bool
    let fs: CGFloat; let activeKeys: [String: Bool]
    let onPress: (MKey) -> Void; let onArrow: (String) -> Void

    var body: some View {
        let unitW = max(1.0, (availW - (KeyboardLayout.gap * 9.0)) / 14.5)
        let halfH = max(1.0, (keyH - KeyboardLayout.gap) / 2.0)

        HStack(spacing: KeyboardLayout.gap) {
            ForEach(KeyboardLayout.leftBottomModifiers) { k in
                KeyBtn(key: k, width: max(1.0, unitW * k.units), height: max(1.0, keyH),
                       capsOn: capsOn, active: activeKeys[k.label.lowercased()] ?? false,
                       fs: fs, onPress: onPress)
            }
            KeyBtn(key: KeyboardLayout.spaceKey, width: max(1.0, unitW * KeyboardLayout.spaceKey.units), height: max(1.0, keyH),
                   capsOn: capsOn, active: false, fs: fs, onPress: onPress)
            ForEach(KeyboardLayout.rightBottomModifiers) { k in
                KeyBtn(key: k, width: max(1.0, unitW * k.units), height: max(1.0, keyH),
                       capsOn: capsOn, active: activeKeys[k.label.lowercased()] ?? false,
                       fs: fs, onPress: onPress)
            }
            HStack(spacing: KeyboardLayout.gap) {
                ArrowBtn(sys: "arrow.left",  w: max(1.0, unitW), h: max(1.0, keyH)) { onArrow("left") }
                VStack(spacing: KeyboardLayout.gap) {
                    ArrowBtn(sys: "arrow.up",   w: max(1.0, unitW), h: halfH) { onArrow("up") }
                    ArrowBtn(sys: "arrow.down", w: max(1.0, unitW), h: halfH) { onArrow("down") }
                }
                ArrowBtn(sys: "arrow.right", w: max(1.0, unitW), h: max(1.0, keyH)) { onArrow("right") }
            }
        }
    }
}
