import UIKit

final class MacPasswordFieldCoordinator: NSObject, UITextFieldDelegate {
    var onCharacterAdded: (Character) -> Void = { _ in }
    var onBackspace: () -> Void = {}
    var onSubmit: () -> Void = {}

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if string.isEmpty {
            onBackspace()
        } else {
            for char in string { onCharacterAdded(char) }
        }
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onSubmit()
        return false
    }
}

struct MacPasswordTextField: UIViewRepresentable {
    var charCount: Int
    var isFocused: Bool
    var onCharacterAdded: (Character) -> Void
    var onBackspace: () -> Void
    var onSubmit: () -> Void

    func makeCoordinator() -> MacPasswordFieldCoordinator {
        MacPasswordFieldCoordinator()
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.isSecureTextEntry = true
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.smartInsertDeleteType = .no
        tf.returnKeyType = .go
        tf.textContentType = .password
        tf.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        tf.textColor = .white
        tf.tintColor = .white
        tf.backgroundColor = .clear
        tf.borderStyle = .none
        tf.attributedPlaceholder = NSAttributedString(
            string: "Password",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.35)]
        )
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.onCharacterAdded = onCharacterAdded
        context.coordinator.onBackspace = onBackspace
        context.coordinator.onSubmit = onSubmit

        let bullet = "●"
        let desired = String(repeating: bullet, count: charCount)
        if tf.text != desired { tf.text = desired }

        if isFocused && !tf.isFirstResponder {
            tf.becomeFirstResponder()
        } else if !isFocused && tf.isFirstResponder {
            tf.resignFirstResponder()
        }
    }
}
