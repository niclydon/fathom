import SwiftUI
import UIKit

/// About this gate: what the two factors are, what they honestly do
/// and do not prove, and how enrollment is reset in the prototype.
struct AboutView: View {
    @Environment(GateController.self) private var gate
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var resetOutcome: String?

    var body: some View {
        ZStack {
            DepthBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("About this gate")
                            .font(.fathomDisplay(26))
                            .foregroundStyle(FathomColor.brass)
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.fathomBody(15))
                            .foregroundStyle(FathomColor.mist)
                    }

                    section("Two factors, in order",
                            "First, a possession factor: the enrolled NFC chip, scanned with the phone. Second, a personhood factor: a World ID Proof of Presence, a fresh face check in the World App, verified by the club's backend against the nullifier enrolled for that chip. The chip arms a two-minute window; the proof must land inside it. Either factor alone opens nothing.")
                    section("What the chip proves, honestly",
                            "The chip's identifier and its stored message are static and can be copied with common gear. A matching scan proves the enrolled chip, or a copy of its contents, is physically here. It does not prove whose hand carries it. That is exactly the gap the World ID proof closes, and why the order matters.")
                    section("What the proof proves",
                            "The World App runs a live presence check and the backend verifies the result with the World Developer Portal, requiring the same enrolled session and rejecting replays. A valid proof from any other person fails. The backend stores a session identifier and a hash of the nullifier only; your World ID humanId never reaches it.")
                    section("If you take this further",
                            "Real chip-side cryptography needs a different chip: an NTAG 424 DNA with dynamic per-tap signatures, a DESFire EV3, or a JavaCard applet. This prototype names those paths instead of pretending a static tag is more than it is.")
                    section("Resetting enrollment",
                            "Reset clears the chip binding and the World session from this phone's Keychain, and asks the backend to clear its enrolled binding. In this single-member prototype that backend clear is one call that wipes the one enrollment; a production club would key bindings per member and protect reset with a stronger ceremony.")

                    ChipDiagnosticsView(scanner: gate.scanner)

                    if gate.isEnrolled || gate.worldClient.isEnrolled {
                        VStack(alignment: .leading, spacing: 10) {
                            ClubHeading(title: "Enrollment")
                            if let binding = gate.binding {
                                Text("Bound mark: \(binding.tagType), enrolled \(binding.enrolledAt.formatted(date: .abbreviated, time: .shortened)).")
                                    .font(.fathomBody(13))
                                    .foregroundStyle(FathomColor.mist)
                            }
                            Button("Reset enrollment") { confirmReset = true }
                                .font(.fathomBody(15))
                                .foregroundStyle(FathomColor.danger)
                            if let resetOutcome {
                                Text(resetOutcome)
                                    .font(.fathomBody(13))
                                    .foregroundStyle(FathomColor.parchment)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .confirmationDialog("Reset enrollment?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset enrollment", role: .destructive) {
                Task { resetOutcome = await gate.resetEnrollment() }
            }
            Button("Keep my enrollment", role: .cancel) {}
        } message: {
            Text("The chip binding leaves this phone and the backend is asked to clear its side. You will bind a mark again from the entrance.")
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.fathomBody(16))
                .fontWeight(.semibold)
                .foregroundStyle(FathomColor.parchment)
            Text(body)
                .font(.fathomBody(14))
                .foregroundStyle(FathomColor.mist)
        }
    }
}

/// The spike, kept: scan any chip and read exactly what iOS exposes,
/// with a copyable report. Useful for checking a new chip before
/// enrollment, and for reporting what a given tag actually presents.
struct ChipDiagnosticsView: View {
    @ObservedObject var scanner: ChipScanner
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClubHeading(title: "Chip Diagnostics")
            Text("Scan a chip to see its type, identifier, and NDEF message exactly as this phone receives them.")
                .font(.fathomBody(13))
                .foregroundStyle(FathomColor.mist)
            GhostButton(title: scanner.isScanning ? "Listening…" : "Scan a chip") {
                scanner.startScan()
            }
            if let err = scanner.lastError {
                Text(err).font(.fathomBody(13)).foregroundStyle(FathomColor.danger)
            }
            if !scanner.scans.isEmpty {
                Button(copied ? "Copied" : "Copy full report") {
                    UIPasteboard.general.string = scanner.fullReport
                    copied = true
                }
                .font(.fathomBody(14))
                .foregroundStyle(FathomColor.brass)
                ForEach(scanner.scans) { scan in
                    Text(scan.reportText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(FathomColor.parchment.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
