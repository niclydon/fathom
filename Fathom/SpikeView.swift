import SwiftUI
import UIKit

/// Fathom NFC spike: scan both implants, twice each, and copy the report.
/// This screen exists to learn what iOS actually exposes for the real
/// chips before enrollment is designed around assumptions. It is
/// replaced by the full Surface / Descent / Club in v0.1.
struct SpikeView: View {
    @StateObject private var scanner = NFCScanner()
    @State private var copied = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.05, blue: 0.09),
                         Color(red: 0.02, green: 0.12, blue: 0.18),
                         Color(red: 0.0, green: 0.02, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("FATHOM")
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .tracking(10)
                            .foregroundStyle(Color(red: 0.83, green: 0.68, blue: 0.42))
                        Text("NFC SPIKE · SIX FATHOMS DOWN")
                            .font(.caption)
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 28)

                    Text("Scan each enrolled chip twice. The phone's NFC antenna is at its top edge: hold the top of the phone against the chip, and hold still for a beat.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Button {
                        scanner.startScan()
                    } label: {
                        Text(scanner.isScanning ? "Listening…" : "Scan a chip")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.83, green: 0.68, blue: 0.42))
                            .foregroundStyle(Color(red: 0.05, green: 0.08, blue: 0.1))
                            .clipShape(Capsule())
                    }
                    .disabled(scanner.isScanning || !scanner.readingAvailable)

                    if !scanner.readingAvailable {
                        Text("NFC tag reading is not available on this device.")
                            .foregroundStyle(.red.opacity(0.9))
                            .font(.callout)
                    }
                    if let err = scanner.lastError {
                        Text(err)
                            .foregroundStyle(.orange.opacity(0.95))
                            .font(.callout)
                    }

                    if !scanner.scans.isEmpty {
                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = scanner.fullReport
                                copied = true
                            } label: {
                                Text(copied ? "Copied ✓" : "Copy full report")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(.white.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Button(role: .destructive) {
                                scanner.scans.removeAll()
                                copied = false
                            } label: {
                                Text("Clear")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(.white)
                    }

                    ForEach(scanner.scans) { scan in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(scan.reportText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("No data leaves this phone. The report stays on screen until you copy it.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}
