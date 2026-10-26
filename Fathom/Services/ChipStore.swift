import Foundation

/// The enrolled chip binding, kept in the Keychain.
///
/// Enrollment stores the tag identifier and the SHA-256 of the full
/// NDEF message. A scan matches only when both match. (Tier-1
/// possession factor: both values are static and cloneable, which is
/// why the World ID proof must follow. See the About screen.)
struct ChipBinding: Equatable {
    var tagType: String
    var identifierHex: String
    var ndefHashHex: String
    var enrolledAt: Date
}

final class ChipStore {
    private let keychain = Keychain()
    private let idKey = "chip_identifier_hex"
    private let hashKey = "chip_ndef_sha256"
    private let typeKey = "chip_tag_type"
    private let dateKey = "chip_enrolled_at"

    var binding: ChipBinding? {
        guard let id = keychain.read(idKey), !id.isEmpty,
              let hash = keychain.read(hashKey), !hash.isEmpty else { return nil }
        return ChipBinding(
            tagType: keychain.read(typeKey) ?? "unknown",
            identifierHex: id,
            ndefHashHex: hash,
            enrolledAt: Date(timeIntervalSince1970: Double(keychain.read(dateKey) ?? "") ?? 0)
        )
    }

    var isEnrolled: Bool { binding != nil }

    /// Enroll from two confirmation scans. Both must agree on the
    /// identifier and the NDEF hash, and the NDEF message must exist.
    func enroll(first: ChipScan, second: ChipScan) -> Result<ChipBinding, ChipError> {
        guard !first.identifierHex.isEmpty, first.identifierHex == second.identifierHex else {
            return .failure(.mismatch("Those two scans were not the same chip. Hold the same mark to the phone both times."))
        }
        guard !first.ndefHashHex.isEmpty else {
            return .failure(.mismatch("That chip's NDEF message could not be read, so there is nothing stable to bind. The mark needs a readable NDEF message."))
        }
        guard first.ndefHashHex == second.ndefHashHex else {
            return .failure(.mismatch("The chip read differently the second time. Hold it still against the top edge of the phone and try again."))
        }
        let binding = ChipBinding(tagType: first.tagType, identifierHex: first.identifierHex, ndefHashHex: first.ndefHashHex, enrolledAt: Date())
        keychain.write(idKey, binding.identifierHex)
        keychain.write(hashKey, binding.ndefHashHex)
        keychain.write(typeKey, binding.tagType)
        keychain.write(dateKey, String(binding.enrolledAt.timeIntervalSince1970))
        return .success(binding)
    }

    func matches(_ scan: ChipScan) -> Bool {
        guard let binding else { return false }
        return scan.identifierHex == binding.identifierHex && scan.ndefHashHex == binding.ndefHashHex
    }

    func clear() {
        keychain.delete(idKey)
        keychain.delete(hashKey)
        keychain.delete(typeKey)
        keychain.delete(dateKey)
    }
}

enum ChipError: LocalizedError {
    case mismatch(String)
    var errorDescription: String? {
        switch self { case .mismatch(let text): return text }
    }
}
