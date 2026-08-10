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
        print("[Flow][Supabase] client initialized url=\(SupabaseConfig.projectURL.absoluteString)")
    }

    @discardableResult
    func ensureSession() async throws -> UUID {
        if let session = try? await client.auth.session {
            print("[Flow][Supabase] ensureSession: reused existing session id=\(session.user.id) expiresAt=\(session.expiresAt)")
            await client.realtimeV2.setAuth(session.accessToken)
            print("[Flow][Supabase] ensureSession: realtimeV2.setAuth applied for existing session")
            return session.user.id
        }
        print("[Flow][Supabase] ensureSession: no existing session, signing in anonymously")
        let session = try await client.auth.signInAnonymously()
        print("[Flow][Supabase] ensureSession: signInAnonymously succeeded id=\(session.user.id)")
        await client.realtimeV2.setAuth(session.accessToken)
        print("[Flow][Supabase] ensureSession: realtimeV2.setAuth applied for new session")
        return session.user.id
    }

    func signOut() async {
        print("[Flow][Supabase] signOut: starting")
        try? await client.auth.signOut()
        print("[Flow][Supabase] signOut: done")
    }
}

enum ConnectionTransport {
    case local
    case remote
}

typealias FlowPeer = DiscoveredPeer
