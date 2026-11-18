//
//  SupabaseManager.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.publishableKey
        )
        flowLog("[Flow][Supabase] client initialized url=\(SupabaseConfig.projectURL.absoluteString)")
    }

    @discardableResult
    func ensureSession() async throws -> UUID {
        do {
            let session = try await client.auth.session
            flowLog("[Flow][Supabase] ensureSession: reused existing session id=\(session.user.id) expiresAt=\(session.expiresAt)")
            await client.realtimeV2.setAuth(session.accessToken)
            return session.user.id
        } catch {
            // A refresh that fails because the network is down must NOT create a new
            // anonymous user – that would silently orphan every paired device.
            if Self.isTransient(error) {
                flowLog("[Flow][Supabase] ensureSession: network problem, keeping existing identity (\(error))")
                throw error
            }
            flowLog("[Flow][Supabase] ensureSession: no usable session (\(error)), signing in anonymously")
        }
        let session = try await client.auth.signInAnonymously()
        flowLog("[Flow][Supabase] ensureSession: signInAnonymously succeeded id=\(session.user.id)")
        await client.realtimeV2.setAuth(session.accessToken)
        return session.user.id
    }

    private static func isTransient(_ error: Error) -> Bool {
        if error is URLError { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError, underlying.domain == NSURLErrorDomain { return true }
        return false
    }

    func signOut() async {
        flowLog("[Flow][Supabase] signOut: starting")
        try? await client.auth.signOut()
        flowLog("[Flow][Supabase] signOut: done")
    }
}

enum ConnectionTransport {
    case local
    case remote
}

typealias FlowPeer = DiscoveredPeer
