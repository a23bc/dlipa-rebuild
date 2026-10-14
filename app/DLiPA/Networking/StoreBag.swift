import Foundation

/// Endpoints discovered in `bag.xml`.
///
/// The plist keys carry a `loc-` prefix on the wire, which is stripped here.
struct StoreBag {
    var authenticateAccount: String?
    var signSapSetup: String?
    var signSapSetupCert: String?
    var signSapVersion: UInt32 = 0
    /// Apple now serves this as `downloaddispatch.itunes.apple.com/.../ent/download`.
    var volumeStoreDownloadProduct: String?
    var redownloadProduct: String?
    var updateProduct: String?

    var hasSAPConfiguration: Bool {
        guard let setup = signSapSetup, let cert = signSapSetupCert else { return false }
        return !setup.isEmpty && !cert.isEmpty && signSapVersion == 200
    }

    /// Parses the bag. Accepts either a top-level `urlBag` dict or a flat dict.
    static func parse(xml data: Data) throws -> StoreBag {
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        guard let root = plist as? [String: Any] else {
            throw StoreError.malformedBag
        }
        let bag = (root["urlBag"] as? [String: Any]) ?? root

        var result = StoreBag()
        result.authenticateAccount = string(bag["authenticateAccount"])
        result.signSapSetup = string(bag["sign-sap-setup"])
        result.signSapSetupCert = string(bag["sign-sap-setup-cert"])
        result.volumeStoreDownloadProduct = string(bag["volumeStoreDownloadProduct"])
        result.redownloadProduct = string(bag["redownloadProduct"])
        result.updateProduct = string(bag["updateProduct"])
        result.signSapVersion = UInt32(string(bag["sign-sap-version"]) ?? "") ?? 0
        return result
    }

    private static func string(_ value: Any?) -> String? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        // Accept both the raw and the `loc-` prefixed form.
        if s.hasPrefix("loc-") { return String(s.dropFirst(4)) }
        return s
    }
}

enum StoreError: LocalizedError {
    case noBagEndpoint
    case malformedBag
    case signingFailed
    case httpError(Int, String)
    case failureType(String, String)

    var errorDescription: String? {
        switch self {
        case .noBagEndpoint:
            return "Apple did not advertise a download endpoint."
        case .malformedBag:
            return "Apple returned an unreadable configuration."
        case .signingFailed:
            return "Failed to sign the request."
        case .httpError(let code, let body):
            return "Apple returned HTTP \(code): \(body)"
        case .failureType(let type, let message):
            return message.isEmpty ? type : message
        }
    }
}
