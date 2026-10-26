import Foundation
import IDKit
import UIKit

enum GateError: LocalizedError {
    case cancelled
    case failed(String)
    case notConfigured(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Cancelled."
        case .failed(let why): return why
        case .notConfigured(let why): return why
        case .unavailable(let why): return why
        }
    }
}

/// The World ID Proof of Presence client for the Descent.
///
/// Flow (World ID 4.0 session proofs, selfie credential):
/// 1. Ask the gate backend for a fresh signed rp_context.
/// 2. First time: create a World ID session through the IDKit bridge
///    (the face check itself runs in the World App, via deep link).
///    Later: prove the saved session the same way.
/// 3. Send the complete IDKit result to the backend, which verifies it
///    with the Developer Portal and enrolls / matches the session.
/// 4. Only a backend-verified success counts.
///
/// The Swift SDK's public wrapper still has its session entry points
/// commented out (checked in idkit-swift 4.2.0), so session create and
/// prove go through the SDK's public UniFFI layer directly; the types
/// are the same ones the wrapper wraps.
///
/// Privacy: this client stores only the verified session_id in the
/// Keychain. No humanId is ever received, stored, or displayed.
/// Adapted from the Cole app's WorldIDClient.
final class WorldIDClient: @unchecked Sendable {
    static var appID: String {
        BuildSecrets.value(forInfoKey: "FATHOM_WORLD_APP_ID") ?? "app_example_replace_me"
    }
    static var gateBaseURL: URL? {
        guard let raw = BuildSecrets.value(forInfoKey: "FATHOM_GATE_BASE_URL") else { return nil }
        return URL(string: raw)
    }

    private let keychain = Keychain()
    var onStatus: (@Sendable (String) -> Void)?

    init() {
        BuildSecrets.seed(keychain, account: "gate_token", fromInfoKey: "FATHOM_GATE_TOKEN")
    }

    private var gateToken: String? {
        let token = keychain.read("gate_token") ?? ""
        return token.isEmpty ? nil : token
    }

    var savedSessionID: String? {
        let value = keychain.read("world_session_id") ?? ""
        return value.isEmpty ? nil : value
    }

    var isEnrolled: Bool { savedSessionID != nil }
    var isConfigured: Bool { gateToken != nil && Self.gateBaseURL != nil }

    func clearSession() { keychain.delete("world_session_id") }

    // MARK: - Backend

    private struct RPContextResponse: Decodable {
        let rp_id: String
        let nonce: String
        let created_at: UInt64
        let expires_at: UInt64
        let signature: String
    }

    func backendPost(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let token = gateToken, let base = Self.gateBaseURL else {
            throw GateError.notConfigured("This build does not carry the gate configuration, so the club's backend cannot be reached.")
        }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            let detail = json["error"] as? String ?? "HTTP \(status)"
            throw GateError.failed("The gate backend said no (\(detail)).")
        }
        return json
    }

    private func fetchRPContext(flow: String) async throws -> RpContext {
        let json = try await backendPost("rp-context", body: ["flow": flow])
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(RPContextResponse.self, from: data)
        return try RpContext(
            rpId: decoded.rp_id,
            nonce: decoded.nonce,
            createdAt: decoded.created_at,
            expiresAt: decoded.expires_at,
            signature: decoded.signature
        )
    }

    // MARK: - IDKit session flow

    func authenticate() async -> Result<Void, GateError> {
        do {
            let enrolled = isEnrolled
            onStatus?("Asking the gate for a signed World ID request.")
            let rpContext = try await fetchRPContext(flow: enrolled ? "prove" : "create")

            let config = IdKitSessionConfig(
                appId: Self.appID,
                packageName: "idkit_swift",
                packageVersion: "4.2.0",
                rpContext: rpContext,
                actionDescription: "Enter the Fathom Club",
                bridgeUrl: nil,
                requireUserPresence: true,
                overrideConnectBaseUrl: nil,
                returnTo: "fathom://worldid-return",
                environment: .production
            )
            let builder = enrolled
                ? IdKitBuilder.fromProveSession(sessionId: savedSessionID ?? "", config: config)
                : IdKitBuilder.fromCreateSession(config: config)
            // Session flows reject presets outright: build the selfie
            // credential request as an explicit constraint instead. This
            // is the FFI form of CredentialRequest("selfie").
            let credential = CredentialRequest.withStringSignal(credentialType: .selfie, signal: nil)
            let request = try builder.constraints(constraints: ConstraintNode.item(request: credential))

            guard let url = URL(string: request.connectUrl()) else {
                return .failure(.failed("World ID returned an unusable handoff link."))
            }
            onStatus?("Opening the World App for your face check.")
            await MainActor.run {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

            onStatus?("Waiting for the World App to finish.")
            let status = await Task.detached { request.pollStatus(pollIntervalMs: 2000, timeoutMs: 300_000) }.value
            switch status {
            case .confirmed(let result):
                onStatus?("Verifying the proof with the gate backend.")
                let resultJSON = try idkitResultToJson(result: result)
                guard let resultObject = try JSONSerialization.jsonObject(with: Data(resultJSON.utf8)) as? [String: Any] else {
                    return .failure(.failed("Could not read the World ID result."))
                }
                var body: [String: Any] = ["flow": enrolled ? "prove" : "enroll", "result": resultObject]
                if let savedSessionID { body["expected_session_id"] = savedSessionID }
                let verified = try await backendPost("verify", body: body)
                guard verified["verified"] as? Bool == true else {
                    return .failure(.failed("The gate backend did not verify that proof."))
                }
                if let sessionID = verified["session_id"] as? String {
                    keychain.write("world_session_id", sessionID)
                }
                return .success(())
            case .failed(let error):
                return .failure(.failed("World ID check failed (\(String(describing: error)))."))
            case .networkingError(let error):
                return .failure(.failed("World ID check hit a network problem (\(String(describing: error)))."))
            case .waitingForConnection, .awaitingConfirmation:
                return .failure(.failed("The World ID check timed out before it finished."))
            }
        } catch let error as GateError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
}
