//
//  CachedAppIconView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

struct CachedAppIconView: View {
    let bundleID: String
    let size: CGFloat
    let cornerRadius: CGFloat
    var isSelected: Bool? = nil
    let factory: FlowViewModelFactory

    @StateObject private var loader: AppIconLoaderViewModel
    @Environment(\.colorScheme) private var scheme

    init(bundleID: String, size: CGFloat, cornerRadius: CGFloat, isSelected: Bool? = nil,
         factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.bundleID = bundleID
        self.size = size
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
        self.factory = factory
        _loader = StateObject(wrappedValue: factory.makeAppIconLoaderViewModel())
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.20, green: 0.20, blue: 0.24) : Color(red: 0.76, green: 0.76, blue: 0.80))
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            }
            if isSelected == true {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(hex: "10B981"), lineWidth: 3.5)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(scheme == .dark ? 0.50 : 0.16), radius: size * 0.12, x: 0, y: size * 0.07)
        .scaleEffect(isSelected == true ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        .onAppear { loader.load(bundleID: bundleID) }
    }
}

struct AppIconTile: View {
    let bundleID: String
    let size: CGFloat
    let cornerRadius: CGFloat
    var isSelected: Bool? = nil

    var body: some View {
        CachedAppIconView(bundleID: bundleID, size: size, cornerRadius: cornerRadius, isSelected: isSelected)
    }
}
