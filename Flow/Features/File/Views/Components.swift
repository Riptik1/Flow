//
//  FileRowButtonStyle.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//


struct FileRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
