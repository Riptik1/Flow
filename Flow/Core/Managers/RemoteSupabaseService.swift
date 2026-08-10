//
//  RemoteSupabaseService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Foundation
import Supabase

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class RemoteSupabaseService {
    static let shared = RemoteSupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }

    @discardableResult
    func ensureSession() async throws -> UUID {
        if let session = try? await client.auth.session {
            return session.user.id
        }
        let session = try await client.auth.signInAnonymously()
        return session.user.id
    }

    func makeChannel(deviceLinkID: UUID) -> RemoteMessageChannel {
        RemoteMessageChannel(deviceLinkID: deviceLinkID, client: client)
    }

    func heartbeat() async {
        guard let deviceID = try? await ensureSession() else { return }
        let table: String
        #if canImport(AppKit)
        table = "mac_devices"
        #else
        table = "iphone_devices"
        #endif
        try? await client
            .from(table)
            .update(["last_seen_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: deviceID.uuidString)
            .execute()
    }

    #if canImport(AppKit)
    @discardableResult
    func ensureRegisteredSession(deviceName: String, deviceModel: String) async throws -> UUID {
        let deviceID = try await ensureSession()
        try await client
            .from("mac_devices")
            .upsert(["id": deviceID.uuidString, "device_name": deviceName, "device_model": deviceModel])
            .execute()
        return deviceID
    }

    func generatePairingCode() async throws -> PairingCodeResponse {
        try await client.functions.invoke(
            "generate-pairing-code",
            options: FunctionInvokeOptions(body: [String: String]())
        )
    }

    func fetchTrustedLinks(macID: UUID) async throws -> [DeviceLinkRow] {
        try await client
            .from("device_links")
            .select()
            .eq("mac_id", value: macID.uuidString)
            .is("revoked_at", value: nil)
            .execute()
            .value
    }

    func fetchIPhoneInfo(id: UUID) async throws -> IPhoneDeviceSummary {
        try await client
            .from("iphone_devices")
            .select("id, device_name, device_model")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }
    #endif

    #if canImport(UIKit)
    @discardableResult
    func ensureRegisteredSession(deviceName: String, deviceModel: String) async throws -> UUID {
        let deviceID = try await ensureSession()
        try await client
            .from("iphone_devices")
            .upsert(["id": deviceID.uuidString, "device_name": deviceName, "device_model": deviceModel])
            .execute()
        return deviceID
    }

    func redeemPairingCode(code: String, deviceName: String, deviceModel: String) async throws -> RedeemPairingCodeResponse {
        try await client.functions.invoke(
            "redeem-pairing-code",
            options: FunctionInvokeOptions(body: [
                "code": code,
                "device_name": deviceName,
                "device_model": deviceModel,
            ])
        )
    }

    func fetchTrustedLinks(iphoneID: UUID) async throws -> [DeviceLinkRow] {
        try await client
            .from("device_links")
            .select()
            .eq("iphone_id", value: iphoneID.uuidString)
            .is("revoked_at", value: nil)
            .execute()
            .value
    }

    func fetchMacInfo(id: UUID) async throws -> MacDeviceSummary {
        try await client
            .from("mac_devices")
            .select("id, device_name, device_model")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }
    #endif
}