import CoreNFC
import CryptoKit
import Foundation
import UIKit

/// One completed chip scan, in the form enrollment and the gate compare.
struct ChipScan: Identifiable, Equatable {
    var id = UUID()
    var at: Date
    var tagType: String
    var identifierHex: String
    var identifierByteCount: Int
    var extra: [String]
    var ndefStatus: String
    var ndefCapacity: Int?
    var ndefRecordDescriptions: [String]
    /// SHA-256 over the full NDEF message (record headers + payloads),
    /// hex. Empty when no NDEF message could be read.
    var ndefHashHex: String
    var errorText: String?

    var reportText: String {
        var lines: [String] = []
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        lines.append("--- Scan at \(fmt.string(from: at)) ---")
        lines.append("tag type: \(tagType)")
        lines.append("identifier: \(identifierHex) (\(identifierByteCount) bytes)")
        for e in extra { lines.append(e) }
        lines.append("NDEF status: \(ndefStatus)")
        if let cap = ndefCapacity { lines.append("NDEF capacity: \(cap) bytes") }
        lines.append("NDEF hash (sha256): \(ndefHashHex.isEmpty ? "(none)" : ndefHashHex)")
        if ndefRecordDescriptions.isEmpty {
            lines.append("NDEF records: none read")
        } else {
            lines.append("NDEF records (\(ndefRecordDescriptions.count)):")
            lines.append(contentsOf: ndefRecordDescriptions)
        }
        if let errorText { lines.append("error: \(errorText)") }
        return lines.joined(separator: "\n")
    }
}

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined(separator: " ") }
    var hexCompact: String { map { String(format: "%02x", $0) }.joined() }
}

/// Core NFC tag scanner for the Descent.
///
/// Polls ISO 14443 and ISO 15693, connects to the first tag, reads its
/// identifier per type, and reads the full NDEF message. It never
/// writes to a tag.
///
/// FeliCa (ISO 18092) polling is deliberately not enabled: iOS requires
/// a separate iso18092 system-codes entitlement for it, and a session
/// that asks for ISO 18092 without that entitlement is invalidated with
/// "Missing required entitlement" (found the hard way on the first
/// spike build, Oct 26, 2026). The chips this gate targets are ISO
/// 14443, so nothing is lost. The FeliCa branch in the tag switch stays
/// for completeness if the entitlement is ever added.
///
/// Tier-1 possession factor, honestly: the identifier and the NDEF
/// message are static and cloneable. This scan proves the enrolled
/// chip (or a copy of its contents) is physically present; the World
/// ID presence proof that follows is what binds it to a person.
final class ChipScanner: NSObject, ObservableObject {
    @Published var scans: [ChipScan] = []
    @Published var lastError: String?
    @Published var isScanning = false

    private var session: NFCTagReaderSession?
    private var completion: ((ChipScan?) -> Void)?

    var readingAvailable: Bool { NFCTagReaderSession.readingAvailable }

    func startScan(completion: ((ChipScan?) -> Void)? = nil) {
        guard NFCTagReaderSession.readingAvailable else {
            lastError = "NFC tag reading is not available on this device."
            completion?(nil)
            return
        }
        lastError = nil
        self.completion = completion
        let newSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
        newSession?.alertMessage = "Hold the top edge of your phone to your mark."
        self.session = newSession
        isScanning = true
        newSession?.begin()
    }

    var fullReport: String {
        var lines: [String] = []
        lines.append("FATHOM CHIP DIAGNOSTICS")
        lines.append("device iOS: \(UIDevice.current.systemVersion)")
        lines.append("scans: \(scans.count)")
        lines.append("")
        for scan in scans {
            lines.append(scan.reportText)
            lines.append("")
        }
        let groups = Dictionary(grouping: scans, by: { $0.identifierHex })
        if scans.count > 1 {
            lines.append("STABILITY")
            for (idHex, group) in groups.sorted(by: { $0.key < $1.key }) where !idHex.isEmpty {
                lines.append("identifier \(idHex): seen \(group.count)x, types: \(Set(group.map(\.tagType)).sorted().joined(separator: ", ")), ndef hashes: \(Set(group.map(\.ndefHashHex)).sorted().joined(separator: ", "))")
            }
            lines.append("distinct identifiers: \(groups.keys.filter { !$0.isEmpty }.count)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: helpers

    private func decodePayload(_ payload: NFCNDEFPayload) -> String {
        var parts: [String] = []
        let typeString = String(data: payload.type, encoding: .ascii) ?? "(non-ascii)"
        parts.append("  - typeNameFormat: \(payload.typeNameFormat.rawValue), type: \"\(typeString)\", id: \(payload.identifier.hexString.isEmpty ? "(none)" : payload.identifier.hexString)")
        parts.append("    payload hex: \(payload.payload.hexString)")
        if let text = String(data: payload.payload, encoding: .utf8), !text.isEmpty {
            parts.append("    payload utf8 (raw): \(text)")
        }
        if typeString == "U", let first = payload.payload.first {
            let prefixes: [UInt8: String] = [
                0x00: "", 0x01: "http://www.", 0x02: "https://www.", 0x03: "http://",
                0x04: "https://", 0x05: "tel:", 0x06: "mailto:", 0x07: "ftp://anonymous:anonymous@",
                0x08: "ftp://ftp.", 0x09: "ftps://", 0x0A: "sftp://", 0x0D: "ftp://",
                0x1D: "file://", 0x23: "urn:nfc:",
            ]
            let rest = String(data: payload.payload.dropFirst(), encoding: .utf8) ?? ""
            parts.append("    decoded URI: \((prefixes[first] ?? "<prefix 0x\(String(format: "%02x", first))>") + rest)")
        }
        if typeString == "T", let first = payload.payload.first {
            let langLen = Int(first & 0x3F)
            let lang = String(data: payload.payload.dropFirst().prefix(langLen), encoding: .ascii) ?? ""
            let text = String(data: payload.payload.dropFirst(1 + langLen), encoding: .utf8) ?? ""
            parts.append("    decoded Text (lang \(lang)): \(text)")
        }
        return parts.joined(separator: "\n")
    }

    private func hashNDEF(_ message: NFCNDEFMessage) -> String {
        var hasher = SHA256()
        for record in message.records {
            hasher.update(data: Data([record.typeNameFormat.rawValue]))
            hasher.update(data: record.type)
            hasher.update(data: record.identifier)
            hasher.update(data: record.payload)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func finish(_ record: ChipScan, session: NFCTagReaderSession, alert: String) {
        let completion = self.completion
        self.completion = nil
        DispatchQueue.main.async {
            if record.identifierHex != "" || record.errorText != nil {
                self.scans.append(record)
            }
            self.isScanning = false
            if record.errorText == nil {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            completion?(record.errorText == nil ? record : nil)
        }
        session.alertMessage = alert
        session.invalidate()
    }
}

extension ChipScanner: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let completion = self.completion
        self.completion = nil
        DispatchQueue.main.async {
            self.isScanning = false
            let code = (error as NSError).code
            // 200 = user cancelled the system scan sheet; not an error.
            if code != 200 {
                self.lastError = error.localizedDescription
                completion?(nil)
            } else {
                completion?(nil)
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                var record = ChipScan(at: Date(), tagType: "unknown", identifierHex: "", identifierByteCount: 0, extra: [], ndefStatus: "not queried", ndefRecordDescriptions: [], ndefHashHex: "")
                record.errorText = "connect failed: \(error.localizedDescription)"
                self.finish(record, session: session, alert: "Could not connect to that chip. Try again.")
                return
            }
            self.readTag(tag, session: session)
        }
    }

    private func readTag(_ tag: NFCTag, session: NFCTagReaderSession) {
        var tagType = "unknown"
        var identifier = Data()
        var extra: [String] = []
        var ndefTag: NFCNDEFTag?

        switch tag {
        case .miFare(let t):
            tagType = "MiFare"
            identifier = t.identifier
            extra.append("miFare family: \(String(describing: t.mifareFamily))")
            ndefTag = t
        case .iso7816(let t):
            tagType = "ISO 7816"
            identifier = t.identifier
            extra.append("initial selected AID: \(t.initialSelectedAID)")
            extra.append("historical bytes: \((t.historicalBytes ?? Data()).hexString)")
            ndefTag = t
        case .iso15693(let t):
            tagType = "ISO 15693"
            identifier = t.identifier
            extra.append("ic manufacturer code: \(t.icManufacturerCode)")
            extra.append("ic serial number: \(t.icSerialNumber.hexString)")
            ndefTag = t
        case .feliCa(let t):
            tagType = "FeliCa"
            identifier = t.currentIDm
            extra.append("current system code: \(t.currentSystemCode.hexString)")
            ndefTag = t
        @unknown default:
            tagType = "unknown (future type)"
        }

        var record = ChipScan(
            at: Date(),
            tagType: tagType,
            identifierHex: identifier.hexString,
            identifierByteCount: identifier.count,
            extra: extra,
            ndefStatus: "not queried",
            ndefRecordDescriptions: [],
            ndefHashHex: ""
        )

        guard let ndefTag else {
            record.ndefStatus = "tag does not expose the NDEF protocol"
            finish(record, session: session, alert: "Chip read (no NDEF).")
            return
        }
        ndefTag.queryNDEFStatus { [weak self] status, capacity, queryError in
            guard let self else { return }
            if let queryError {
                record.ndefStatus = "query failed: \(queryError.localizedDescription)"
                self.finish(record, session: session, alert: "Chip read. NDEF status could not be queried.")
                return
            }
            record.ndefCapacity = capacity
            switch status {
            case .notSupported: record.ndefStatus = "notSupported"
            case .readOnly: record.ndefStatus = "readOnly"
            case .readWrite: record.ndefStatus = "readWrite"
            @unknown default: record.ndefStatus = "unknown (\(status.rawValue))"
            }
            guard status != .notSupported else {
                self.finish(record, session: session, alert: "Chip read. It has no NDEF support.")
                return
            }
            ndefTag.readNDEF { message, readError in
                if let readError {
                    record.errorText = "NDEF read failed: \(readError.localizedDescription)"
                    self.finish(record, session: session, alert: "Chip read. Its NDEF message could not be read.")
                    return
                }
                if let message {
                    record.ndefRecordDescriptions = message.records.map { self.decodePayload($0) }
                    record.ndefHashHex = self.hashNDEF(message)
                }
                self.finish(record, session: session, alert: "Chip read.")
            }
        }
    }
}
