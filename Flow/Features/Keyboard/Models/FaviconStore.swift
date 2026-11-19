//
//  FaviconStore.swift
//  Flow
//
//  Website icons sent by the Mac for the Touch Bar browser tabs.
//

import Combine
import SwiftUI
import UIKit

final class FaviconStore: ObservableObject {
    static let shared = FaviconStore()

    @Published private(set) var images: [String: UIImage] = [:]

    private init() {}

    func set(host: String, png: Data) {
        guard let image = UIImage(data: png) else { return }
        images[host] = image
    }

    func image(forURL urlString: String) -> UIImage? {
        guard let host = URL(string: urlString)?.host else { return nil }
        return images[host]
    }
}
