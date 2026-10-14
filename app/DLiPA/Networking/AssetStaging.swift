import Foundation

/// Copies the bundled Apple SAP binaries into the caches directory on first
/// launch and points the Go bridge at them.
///
/// The Go asset loader validates size and SHA-256, so a corrupt copy fails
/// loudly here rather than as an opaque handshake error later.
enum AssetStaging {
    private static let files = [
        "AppleMediaServices": 14813888,
        "commerce": 8092640,
        "CoreFP": 94842464,
        "CoreFP.icxs": 7365344,
    ]

    static var stagedDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SapAssets", isDirectory: true)
    }

    static func stageIfNeeded() {
        let fm = FileManager.default
        let destination = stagedDirectory

        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            print("[assets] cannot create \(destination.path): \(error)")
            return
        }

        for (name, expectedSize) in files {
            let target = destination.appendingPathComponent(name)

            if let attributes = try? fm.attributesOfItem(atPath: target.path),
               (attributes[.size] as? Int) == expectedSize {
                continue // already staged
            }

            guard let source = Bundle.main.url(forResource: name, withExtension: nil) else {
                print("[assets] \(name) is missing from the app bundle")
                continue
            }

            do {
                if fm.fileExists(atPath: target.path) {
                    try fm.removeItem(at: target)
                }
                try fm.copyItem(at: source, to: target)
                print("[assets] staged \(name)")
            } catch {
                print("[assets] failed to stage \(name): \(error)")
            }
        }

        Sapbridge.setBundleDir(destination.path)
    }
}
