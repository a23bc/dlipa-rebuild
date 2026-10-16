# TrollStore install error 181: fixed

    DLiPA-unsigned.ipa    91.20 MB
    sha256  e124e17762fa35722694d49b1fb559f58a08720b26288dad5d4ead07b2a2d7d5
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/38882085068

## What the log said

Not a signing failure. Every step that could fail on code signing
succeeded:

    ldid exited with status 0            (twice)
    Applied CoreTrust bypass!            (framework and main binary)
    ApplicationType = System             <-- this
    Error: Unable to register .../DLiPA.app
    trollstorehelper returning 181

`ApplicationType = System` is the tell. MobileInstallation assigns it when a
bundle does not look like an application, and then registration fails with
181. The app icon was never the problem, though it was also wrong.

## Cause: an incomplete scene manifest

The app has a `SceneDelegate`, so Info.plist must declare the scene
configuration that instantiates it. It did not. Diffing our Info.plist
against the original found four gaps:

| Key | Was |
|---|---|
| UIApplicationSceneManifest | absent entirely |
| CFBundleSupportedPlatforms | absent |
| CFBundleIcons / ~ipad | a bare CFBundleIconFiles list naming an invented file |
| UIBackgroundModes | absent |

## Fix, verified in the shipped artifact

All nine install-critical keys are now identical to a build known to install.
Checked by loading the Info.plist **out of the IPA** and comparing it to the
original, not by reading the project file:

    UIApplicationSceneManifest      IDENTICAL
    CFBundleSupportedPlatforms      IDENTICAL
    CFBundleIcons                   IDENTICAL
    CFBundleIcons~ipad              IDENTICAL
    UIBackgroundModes               IDENTICAL
    CFBundlePackageType             IDENTICAL
    LSRequiresIPhoneOS              IDENTICAL
    UIDeviceFamily                  IDENTICAL
    CFBundleInfoDictionaryVersion   IDENTICAL

    CFBundleIdentifier  com.a23bc.dliparebuild
    MinimumOSVersion    15.0
    SceneDelegate class SceneDelegate

The icon uses the upstream files under their real names rather than anything
regenerated: `AppIcon60x60@2x.png` (120x120) and `AppIcon76x76@2x~ipad.png`
(152x152), both present in the shipped bundle.

## Licensing

Added `LICENSE` and `NOTICE.md`.

The rebuild's own code is MIT. NOTICE.md records what is not ours:

- `sapbridge/internal/sap/` is a trimmed vendored copy of **ipatool v2**
  (MIT, Majd Alfhaily), including the two-leg handshake, the kbsync blob, the
  ent/download request shape and the iOS W^X patch
- **Unicorn** is GPL v2 with a linking exception; fetched at build time, not
  vendored
- the four Go dependencies with their licenses: go-macho (MIT), purego
  (Apache 2.0), howett.net/plist (BSD 2-Clause), x/mobile (BSD 3-Clause)
- the Apple binaries in `VendorAssets/` are Apple copyright
- the icon and the 14 Localizable.strings come from the original DLiPA 1.4,
  whose repository states **no license**. NOTICE says so explicitly rather
  than implying a license it does not have.

One thing worth flagging: because the original publishes no license, reusing
its icon and strings is a judgement call, not a clearly granted right. They
are there so this is a drop-in replacement, and they are easy to replace with
originals if you would rather not carry them.
