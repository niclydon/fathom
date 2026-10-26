import Foundation
import SwiftUI
import UIKit

/// Owns the Descent sequence and the club lock.
///
/// Rules, in order, fail closed:
/// - Enrollment: scan the chip twice (both scans must agree), then the
///   first verified World ID presence proof enrolls the nullifier on
///   the backend and completes the chip <-> nullifier binding.
/// - Unlock: Step A scans the chip and must match enrollment; a pass
///   arms Step B for 120 seconds. Step B is a World ID presence proof
///   verified by the backend against the enrolled nullifier/session.
///   Both steps, in sequence, inside the window, or nothing opens.
/// - "Return to the surface" locks immediately. Backgrounding the app
///   while inside the club for longer than a 60 second grace relocks
///   (the grace pattern is adapted from the Cole app's ModeController).
@Observable
final class GateController {
    enum Phase: Equatable {
        case idle
        case enrollAwaitFirstScan
        case enrollAwaitSecondScan(first: ChipScan)
        case enrollAwaitWorld(first: ChipScan)
        case chipArmed(until: Date)
        case provingWorld
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var inClub = false
    var worldStatus: String?

    /// Seconds the chip pass arms the World step. Spec: 120.
    let armWindow: TimeInterval = 120
    /// Seconds in the background before the club relocks. Spec: 60.
    var relockGrace: TimeInterval = 60
    private var backgroundedAt: Date?

    let scanner = ChipScanner()
    let chipStore = ChipStore()
    let worldClient = WorldIDClient()

    var isEnrolled: Bool { chipStore.isEnrolled }
    var binding: ChipBinding? { chipStore.binding }

    private var armTimer: Task<Void, Never>?

    init() {
        worldClient.onStatus = { [weak self] text in
            Task { @MainActor in self?.worldStatus = text }
        }
    }

    // MARK: - Enrollment

    func beginEnrollment() {
        phase = .enrollAwaitFirstScan
        scanner.startScan { [weak self] scan in
            guard let self else { return }
            guard let scan else { self.fail("The scan was cancelled. Nothing was enrolled."); return }
            if !scan.ndefHashHex.isEmpty || !scan.identifierHex.isEmpty {
                self.phase = .enrollAwaitSecondScan(first: scan)
            } else {
                self.fail("That scan did not read a chip. Hold the top edge of the phone to your mark and try again.")
            }
        }
    }

    func confirmEnrollmentScan() {
        guard case .enrollAwaitSecondScan(let first) = phase else { return }
        scanner.startScan { [weak self] scan in
            guard let self else { return }
            guard let scan else { self.fail("The second scan was cancelled. Nothing was enrolled."); return }
            switch self.chipStore.enroll(first: first, second: scan) {
            case .success:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.phase = .enrollAwaitWorld(first: first)
            case .failure(let error):
                self.fail(error.localizedDescription)
            }
        }
    }

    /// The first World proof after chip enrollment completes the binding.
    func completeEnrollmentWithWorld() async {
        guard case .enrollAwaitWorld = phase else { return }
        phase = .provingWorld
        let result = await worldClient.authenticate()
        worldStatus = nil
        switch result {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            enterClub()
        case .failure(let error):
            // Chip binding stays on the phone; the backend has nothing
            // enrolled, so the binding completes on a later pass.
            fail(error.localizedDescription)
        }
    }

    // MARK: - Unlock sequence

    /// Step A: present your mark.
    func beginUnlock() {
        phase = .idle
        scanner.startScan { [weak self] scan in
            guard let self else { return }
            guard let scan else { self.fail("The scan was cancelled."); return }
            if self.chipStore.matches(scan) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let until = Date().addingTimeInterval(self.armWindow)
                self.phase = .chipArmed(until: until)
                self.startArmTimer(until: until)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                self.fail("That is not the enrolled mark. The descent resets.")
            }
        }
    }

    /// Step B: prove you're you. Only reachable while armed.
    func proveWithWorld() async {
        guard case .chipArmed = phase else { return }
        armTimer?.cancel()
        phase = .provingWorld
        let result = await worldClient.authenticate()
        worldStatus = nil
        switch result {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            enterClub()
        case .failure(let error):
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            fail(error.localizedDescription)
        }
    }

    private func startArmTimer(until: Date) {
        armTimer?.cancel()
        armTimer = Task { [weak self] in
            let delay = until.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, case .chipArmed = self.phase else { return }
                self.fail("The window closed before the proof finished. Begin again.")
            }
        }
    }

    // MARK: - Club lock

    func enterClub() {
        phase = .idle
        inClub = true
        backgroundedAt = nil
    }

    /// "Return to the surface."
    func lock() {
        armTimer?.cancel()
        phase = .idle
        inClub = false
        backgroundedAt = nil
    }

    func fail(_ message: String) {
        armTimer?.cancel()
        phase = .failed(message)
    }

    func resetToIdle() {
        armTimer?.cancel()
        phase = .idle
    }

    func scenePhaseChanged(to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if inClub { backgroundedAt = .now }
        case .active:
            guard inClub, let since = backgroundedAt else { return }
            backgroundedAt = nil
            if Date.now.timeIntervalSince(since) > relockGrace {
                lock()
            }
        default:
            break
        }
    }

    // MARK: - Reset enrollment

    /// Clears the phone-side binding and session, and asks the backend
    /// to clear the enrolled nullifier binding. Prototype semantics:
    /// the deployment is single-member, so the backend call clears the
    /// one enrolled binding; the next enrollment starts fresh.
    /// Returns a plain-language outcome for the About screen.
    func resetEnrollment() async -> String {
        lock()
        chipStore.clear()
        worldClient.clearSession()
        do {
            _ = try await worldClient.backendPost("reset-enrollment", body: [:])
            return "Enrollment reset. The chip binding is gone from this phone, and the backend's enrolled binding was cleared. You can bind a mark again from the entrance."
        } catch {
            return "The chip binding is gone from this phone. The backend clear could not be confirmed (\(error.localizedDescription)), so if a fresh enrollment is refused, clear the backend's state file on the server and restart the gate service."
        }
    }
}
