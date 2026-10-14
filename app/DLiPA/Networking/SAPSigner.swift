import Foundation

/// The device identity used for SAP signing and kbsync generation.
///
/// Must be exactly 6 bytes: `ent/download` rejects any other length, and the
/// original DLiPA used a random UUID which cannot work there.
struct HardwareIdentity {
    /// Raw 6 bytes.
    let bytes: Data

    /// Uppercase hex, e.g. `A4B2C3D4E5F6`. Used as the `guid` query parameter
    /// and the plist `guid` field.
    var guid: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }

    /// A stable 6-byte identity.
    ///
    /// iOS exposes no MAC address, so the first 6 bytes of the vendor
    /// identifier's SHA-256 are pinned. This is stable across launches, which
    /// matters because a cached kbsync blob is only valid for the identity that
    /// produced it.
    static func stable() -> HardwareIdentity {
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? "dlipa-fallback"
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        seed.data(using: .utf8)!.withUnsafeBytes { pointer in
            CC_SHA256(pointer.baseAddress, CC_LONG(seed.data(using: .utf8)!.count), &digest)
        }
        return HardwareIdentity(bytes: Data(digest.prefix(6)))
    }
}

/// Owns the SAP session. Create once after login and share for the whole
/// session; the session is stateful, so re-signing is required after any
/// redirect.
final class SAPSigner {
    private let signer: SapbridgeSigner
    let hardware: HardwareIdentity

    init(setupURL: String, certURL: String, version: UInt32, hardware: HardwareIdentity) throws {
        var error: NSError?
        guard let s = Sapbridge.newSigner(setupURL,
                                         certURL: certURL,
                                         version: Int64(version),
                                         hardware: hardware.bytes,
                                         error: &error), error == nil else {
            throw error ?? NSError(domain: "SAPSigner", code: 1, userInfo: nil)
        }
        self.signer = s
        self.hardware = hardware
    }

    /// The value for the `X-Apple-ActionSignature` header.
    func signatureHeaderValue(for body: Data) throws -> String {
        var error: NSError?
        guard let value = signer.signatureHeaderValue(body, error: &error), error == nil else {
            throw error ?? NSError(domain: "SAPSigner", code: 2, userInfo: nil)
        }
        return value
    }

    /// The FairPlay kbsync blob required by `ent/download`.
    func kbsync(dsid: String) throws -> Data {
        var error: NSError?
        guard let blob = Sapbridge.kbsync(hardware.bytes,
                                         dsid: try Self.parseDSID(dsid),
                                         error: &error), error == nil else {
            throw error ?? NSError(domain: "SAPSigner", code: 3, userInfo: nil)
        }
        return blob
    }

    /// `ent/download`'s serialNumber: base64(54 c8 b0 a9 88 ++ guid[2:]).
    func serialNumber() throws -> String {
        var error: NSError?
        guard let value = Sapbridge.serialNumber(hardware.bytes, error: &error), error == nil else {
            throw error ?? NSError(domain: "SAPSigner", code: 4, userInfo: nil)
        }
        return value
    }

    static func parseDSID(_ value: String) throws -> Int64 {
        var error: NSError?
        let parsed = Sapbridge.parseDSID(value, error: &error)
        if let error { throw error }
        guard parsed != 0 else {
            throw NSError(domain: "SAPSigner",
                          code: 5,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "ent/download requires a nonzero decimal DSID"])
        }
        return parsed
    }

    func close() {
        signer.close()
    }
}
