//
//  FlowBackendClient.swift
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

final class FlowBackendClient {
    static let shared = FlowBackendClient()

    private let manager = SupabaseManager.shared
    private var client: SupabaseClient { manager.client }

    private init() {}

    func makeChannel(deviceLinkID: UUID) -> RemoteMessageChannel {
        print("[Flow][Backend] makeChannel: deviceLinkID=\(deviceLinkID)")
        return RemoteMessageChannel(deviceLinkID: deviceLinkID, client: client)
    }

    func heartbeat() async {
        guard let deviceID = try? await manager.ensureSession() else {
            print("[Flow][Backend] heartbeat: ensureSession FAILED, skipping")
            return
        }
        let table: String
        #if canImport(AppKit)
        table = "mac_devices"
        #else
        table = "iphone_devices"
        #endif
        do {
            try await client
                .from(table)
                .update(["last_seen_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: deviceID.uuidString)
                .execute()
            print("[Flow][Backend] heartbeat: updated \(table).last_seen_at for id=\(deviceID)")
        } catch {
            print("[Flow][Backend] heartbeat: FAILED table=\(table) id=\(deviceID) error=\(error)")
        }
    }

    func leaveDeviceGroup() async throws {
        print("[Flow][Backend] leaveDeviceGroup: invoking edge function")
        struct EmptyResponse: Decodable {}
        do {
            let _: EmptyResponse = try await client.functions.invoke(
                "leave-device-group",
                options: FunctionInvokeOptions(body: [String: String]())
            )
            print("[Flow][Backend] leaveDeviceGroup: succeeded")
        } catch {
            print("[Flow][Backend] leaveDeviceGroup: FAILED error=\(error)")
            throw error
        }
    }

    func revokeDeviceLink(id: UUID) async throws {
        print("[Flow][Backend] revokeDeviceLink: id=\(id)")
        do {
            try await client
                .from("device_links")
                .update(["revoked_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: id.uuidString)
                .execute()
            print("[Flow][Backend] revokeDeviceLink: succeeded id=\(id)")
        } catch {
            print("[Flow][Backend] revokeDeviceLink: FAILED id=\(id) error=\(error)")
            throw error
        }
    }

    #if canImport(AppKit)
    @discardableResult
    func ensureRegisteredSession(deviceName: String, deviceModel: String) async throws -> UUID {
        print("[Flow][Backend] ensureRegisteredSession(Mac): deviceName=\(deviceName) deviceModel=\(deviceModel)")
        let deviceID = try await manager.ensureSession()
        do {
            try await client
                .from("mac_devices")
                .upsert(["id": deviceID.uuidString, "device_name": deviceName, "device_model": deviceModel])
                .execute()
            print("[Flow][Backend] ensureRegisteredSession(Mac): upsert succeeded id=\(deviceID)")
        } catch {
            print("[Flow][Backend] ensureRegisteredSession(Mac): upsert FAILED id=\(deviceID) error=\(error)")
            throw error
        }
        return deviceID
    }

    func generatePairingCode() async throws -> PairingCodeResponse {
        print("[Flow][Backend] generatePairingCode: invoking edge function")
        do {
            let response: PairingCodeResponse = try await client.functions.invoke(
                "generate-pairing-code",
                options: FunctionInvokeOptions(body: [String: String]())
            )
            print("[Flow][Backend] generatePairingCode: succeeded code=\(response.code) expiresAt=\(response.expiresAt)")
            return response
        } catch {
            print("[Flow][Backend] generatePairingCode: FAILED error=\(error)")
            throw error
        }
    }

    func fetchTrustedLinks(macID: UUID) async throws -> [DeviceLinkRow] {
        do {
            let links: [DeviceLinkRow] = try await client
                .from("device_links")
                .select()
                .eq("mac_id", value: macID.uuidString)
                .is("revoked_at", value: nil)
                .execute()
                .value
            print("[Flow][Backend] fetchTrustedLinks(mac): macID=\(macID) found \(links.count) link(s)")
            return links
        } catch {
            print("[Flow][Backend] fetchTrustedLinks(mac): macID=\(macID) FAILED error=\(error)")
            throw error
        }
    }

    func fetchIPhoneInfo(id: UUID) async throws -> IPhoneDeviceSummary {
        do {
            let summary: IPhoneDeviceSummary = try await client
                .from("iphone_devices")
                .select("id, device_name, device_model")
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
            print("[Flow][Backend] fetchIPhoneInfo: id=\(id) -> \(summary.deviceName)/\(summary.deviceModel)")
            return summary
        } catch {
            print("[Flow][Backend] fetchIPhoneInfo: id=\(id) FAILED error=\(error)")
            throw error
        }
    }
    #endif

    #if canImport(UIKit)
    @discardableResult
    func ensureRegisteredSession(deviceName: String, deviceModel: String) async throws -> UUID {
        print("[Flow][Backend] ensureRegisteredSession(iPhone): deviceName=\(deviceName) deviceModel=\(deviceModel)")
        let deviceID = try await manager.ensureSession()
        do {
            try await client
                .from("iphone_devices")
                .upsert(["id": deviceID.uuidString, "device_name": deviceName, "device_model": deviceModel])
                .execute()
            print("[Flow][Backend] ensureRegisteredSession(iPhone): upsert succeeded id=\(deviceID)")
        } catch {
            print("[Flow][Backend] ensureRegisteredSession(iPhone): upsert FAILED id=\(deviceID) error=\(error)")
            throw error
        }
        return deviceID
    }

    func redeemPairingCode(code: String, deviceName: String, deviceModel: String) async throws -> RedeemPairingCodeResponse {
        print("[Flow][Backend] redeemPairingCode: code=\(code) deviceName=\(deviceName) deviceModel=\(deviceModel)")
        do {
            let response: RedeemPairingCodeResponse = try await client.functions.invoke(
                "redeem-pairing-code",
                options: FunctionInvokeOptions(body: [
                    "code": code,
                    "device_name": deviceName,
                    "device_model": deviceModel,
                ])
            )
            print("[Flow][Backend] redeemPairingCode: succeeded linkID=\(response.deviceLinkID) macID=\(response.mac.id)")
            return response
        } catch {
            print("[Flow][Backend] redeemPairingCode: FAILED error=\(error)")
            throw error
        }
    }

    func fetchTrustedLinks(iphoneID: UUID) async throws -> [DeviceLinkRow] {
        do {
            let links: [DeviceLinkRow] = try await client
                .from("device_links")
                .select()
                .eq("iphone_id", value: iphoneID.uuidString)
                .is("revoked_at", value: nil)
                .execute()
                .value
            print("[Flow][Backend] fetchTrustedLinks(iphone): iphoneID=\(iphoneID) found \(links.count) link(s)")
            return links
        } catch {
            print("[Flow][Backend] fetchTrustedLinks(iphone): iphoneID=\(iphoneID) FAILED error=\(error)")
            throw error
        }
    }

    func fetchMacInfo(id: UUID) async throws -> MacDeviceSummary {
        do {
            let summary: MacDeviceSummary = try await client
                .from("mac_devices")
                .select("id, device_name, device_model")
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
            print("[Flow][Backend] fetchMacInfo: id=\(id) -> \(summary.deviceName)/\(summary.deviceModel)")
            return summary
        } catch {
            print("[Flow][Backend] fetchMacInfo: id=\(id) FAILED error=\(error)")
            throw error
        }
    }
    #endif
}
