import SwiftUI

/// The Descent: the gate itself, order enforced by GateController.
/// Enrollment (first time) binds the mark; after that, the entrance is
/// Step A (chip) then Step B (World ID presence), in sequence, inside
/// a 120 second window, or it fails closed and the sequence restarts.
struct DescentView: View {
    @Environment(GateController.self) private var gate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DepthBackground()
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Surface") { gate.resetToIdle(); dismiss() }
                        .font(.fathomBody(14))
                        .foregroundStyle(FathomColor.mist)
                }
                Text("THE DESCENT")
                    .font(.fathomDisplay(30))
                    .tracking(6)
                    .foregroundStyle(FathomColor.brass)
                content
                Spacer()
            }
            .padding(24)
        }
        .onChange(of: gate.inClub) { _, inClub in
            if inClub { dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !gate.isEnrolled {
            enrollment
        } else if gate.inClub {
            Text("Welcome below.")
                .font(.fathomBody(17))
                .foregroundStyle(FathomColor.parchment)
        } else {
            unlock
        }
    }

    // MARK: - Enrollment

    @ViewBuilder
    private var enrollment: some View {
        VStack(spacing: 18) {
            Text("Bind your mark")
                .font(.fathomDisplay(22))
                .foregroundStyle(FathomColor.parchment)
            switch gate.phase {
            case .enrollAwaitSecondScan:
                Text("Once more, to be sure it was not chance. Scan the same mark again.")
                    .descentCopy()
                BrassButton(title: "Scan it again") { gate.confirmEnrollmentScan() }
            case .enrollAwaitWorld:
                Text("The mark is held. Now prove the mark is yours: a World ID presence proof, face to face with the World App. This first proof enrolls you on the club's backend and completes the binding.")
                    .descentCopy()
                if let status = gate.worldStatus {
                    Text(status).font(.fathomBody(13)).foregroundStyle(FathomColor.mist)
                }
                BrassButton(title: "Prove you're you") {
                    Task { await gate.completeEnrollmentWithWorld() }
                }
            case .provingWorld:
                ProgressView().tint(FathomColor.brass)
                Text(gate.worldStatus ?? "Proving…")
                    .font(.fathomBody(14))
                    .foregroundStyle(FathomColor.mist)
            case .failed(let message):
                failure(message)
                BrassButton(title: "Begin again") { gate.resetToIdle() }
            default:
                Text("Fathom binds two things together: a chip you carry, and the one person you are. First, the chip. The phone's antenna is at its top edge, so hold the top of the phone to your mark and hold still.")
                    .descentCopy()
                BrassButton(title: "Scan my mark") { gate.beginEnrollment() }
            }
        }
    }

    // MARK: - Unlock

    @ViewBuilder
    private var unlock: some View {
        VStack(spacing: 18) {
            switch gate.phase {
            case .chipArmed(let until):
                Text("The mark is known.")
                    .font(.fathomDisplay(22))
                    .foregroundStyle(FathomColor.parchment)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let remaining = max(0, Int(until.timeIntervalSinceNow))
                    Text("Step one is done. The door stays armed for \(remaining) seconds. Step two: prove you're you.")
                        .descentCopy()
                }
                if let status = gate.worldStatus {
                    Text(status).font(.fathomBody(13)).foregroundStyle(FathomColor.mist)
                }
                BrassButton(title: "Prove you're you") {
                    Task { await gate.proveWithWorld() }
                }
            case .provingWorld:
                ProgressView().tint(FathomColor.brass)
                Text(gate.worldStatus ?? "Proving…")
                    .font(.fathomBody(14))
                    .foregroundStyle(FathomColor.mist)
            case .failed(let message):
                failure(message)
                BrassButton(title: "Begin again") { gate.resetToIdle() }
            default:
                Text("Step A · Present your mark")
                    .font(.fathomDisplay(22))
                    .foregroundStyle(FathomColor.parchment)
                Text("Hold the top edge of the phone to your mark. A known mark arms the door for two minutes; the proof of presence must land inside them.")
                    .descentCopy()
                BrassButton(title: "Present my mark") { gate.beginUnlock() }
            }
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.title2)
                .foregroundStyle(FathomColor.danger)
            Text(message)
                .font(.fathomBody(15))
                .foregroundStyle(FathomColor.parchment)
                .multilineTextAlignment(.center)
        }
    }
}

private extension View {
    func descentCopy() -> some View {
        self.font(.fathomBody(15))
            .foregroundStyle(FathomColor.mist)
            .multilineTextAlignment(.center)
    }
}
