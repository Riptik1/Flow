//
//  PremiumExpiredAlert.swift
//  Flow
//
//  One alert for every premium feature once the free access is over.
//

import SwiftUI

extension View {
    /// "Your 2-day free access is over" alert; OK takes the user to the subscription screen.
    func premiumExpiredAlert(isPresented: Binding<Bool>, feature: String, onSubscribe: @escaping () -> Void) -> some View {
        alert("Free access ended", isPresented: isPresented) {
            Button("OK") { onSubscribe() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your 2-day free access is over. Subscribe to keep using \(feature).")
        }
    }
}
