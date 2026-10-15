import CryptoKit
import Foundation
import UIKit

/// The device identity used for SAP signing and kbsync generation.
///
/// Must be exactly 6 bytes: `ent/download` rejects any other length, and the
/// original DLiPA used a random UUID which cannot work there.
struct HardwareIdentity {
    /// Raw bytes. Must be 6 for `ent/download`.
    let bytes: Data

    /// Uppercase hex, e.g. `A4B2C3D4E5F6`. Used as the `guid` query parameter
    /// and the plist `guid` field.
    var guid: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }

    /// A stable 6-byte identity.
    ///
    /// iOS exposes no MAC address, so the first 6 bytes of the vendor
    /// identifier UUID string are used. This is stable across launches, which
    /// matters because a cached kbsync blob is only valid for the identity that
    /// produced it.
    static func stable() -> HardwareIdentity {
        // identifierForVendor survives app restarts on the same device. It is
        // reset only when the user removes every app from the vendor, which
        // also invalidates any cached kbsync - an acceptable trade.
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? "dlipa-fallback"
        let data = Data(seed.utf8)
        // SHA-256 over the UUID string, first 6 bytes kept.
        let digest = Array(SHA256.hash(data: data))
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
    ///
    /// Generating a blob spins up the Unicorn guest and the Apple binaries,
    /// which is expensive, and the blob is stable for a given account and
    /// device. So it is cached and reused. A blob Apple rejected is
    /// discarded so the next call regenerates it; a freshly generated blob
    /// is never retried, because a second failure means something is wrong.
    func kbsync(dsid: String) throws -> Data {
        let numeric = try Self.parseDSID(dsid)
        let key = Self.cacheKey(dsid: numeric, guid: hardware.guid)

        if let cached = Self.kbsyncCache.object(forKey: key) {
            return cached as Data
        }

        let fresh = try generateKBSync(dsid: numeric)
        Self.kbsyncCache.setObject(fresh as NSData, forKey: key)
        return fresh
    }

    /// Drops a cached blob so the next call regenerates it. Call this when
    /// Apple rejects a download, which ipatool treats as a stale blob.
    func invalidateKBSync(dsid: String) {
        guard let numeric = try? Self.parseDSID(dsid) else { return }
        Self.kbsyncCache.removeObject(forKey: Self.cacheKey(dsid: numeric, guid: hardware.guid))
    }

    private func generateKBSync(dsid: Int64) throws -> Data {
        var error: NSError?
        guard let blob = Sapbridge.kbsync(hardware.bytes,
                                         dsid: dsid,
                                         error: &error), error == nil else {
            throw error ?? NSError(domain: "SAPSigner", code: 3, userInfo: nil)
        }
        return blob
    }

    // MARK: kbsync cache

    /// In-memory only. A blob is bound to an account and a device, and the
    /// device identity is stable, so there is nothing to persist.
    private static let kbsyncCache = NSMapTable<NSString, NSData>.strongToStrongObjects()

    private static func cacheKey(dsid: Int64, guid: String) -> NSString {
        return "\(dsid):\(guid)" as NSString
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
