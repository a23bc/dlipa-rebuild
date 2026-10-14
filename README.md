# DLiPA — SAP-adapted rebuild

DLiPA stopped working because Apple now requires App Store private-API requests
to carry an `X-Apple-ActionSignature` header, and because the download endpoint
 advertised in `bag.xml` moved to `ent/download`. This repository rebuilds the
app with both changes, and builds an installable IPA on GitHub Actions.

**No Apple Developer account is required.** The IPA is built unsigned and you
sign it with your own Apple ID using AltStore or Sideloadly — the same flow the
original DLiPA README recommended.

---

## What was wrong, and what changed

| Problem | Evidence | Fix here |
|---|---|---|
| Requests were unsigned | Signed request -> HTTP 200 + session cookie; unsigned -> **HTTP 403** | `sapbridge` signs every body |
| authenticate URL lacked a trailing slash | Without it Apple answers **HTTP 204** empty; with it, HTTP 200 | `AppStoreClient.authenticate` appends `/` |
| Download URL was hardcoded to the legacy MZFinance path | Live bag now returns `downloaddispatch.itunes.apple.com/.../ent/download` for `volumeStoreDownloadProduct` | `AppStoreClient.requestDownload` uses the bag value |
| No kbsync blob | `ent/download` requires FairPlay kbsync | `SAPSigner.kbsync` |
| guid was a random UUID | `ent/download` requires a 6-byte GUID | `HardwareIdentity.stable()` |
| dsid was a string | `ent/download` requires a decimal DSID | `SAPSigner.parseDSID` |

The controlled experiment behind the first two rows is in
`../SIGNATURE_EXPERIMENT.md`.

---

## Layout

    app/                        Xcode project (XcodeGen) + Swift sources
      project.yml
      DLiPA/
        Info.plist
        LaunchScreen.storyboard
        SapBridge.h             contract for the Go framework
        AppDelegate.swift
        SceneDelegate.swift
        MainViewController.swift
        Networking/
          AppStoreClient.swift   signed transport, bag, login, download
          StoreBag.swift         bag.xml parsing (handles loc- prefix)
          SAPSigner.swift        wraps the Go bridge
          AssetStaging.swift     copies the 119 MB assets out of the bundle
    sapbridge/                  Go module: the Apple SAP signing stack
      sapbridge.go             Sign / SignatureHeaderValue / KBSync / SerialNumber
      internal/sap/...         vendored from majd/ipatool v2 (MIT)
      *_test.go                9 unit tests, all passing
      VERIFICATION.md          build/test matrix
    scripts/
      build-unicorn-ios.sh     cross-compiles Unicorn (arch=aarch64)
      stage-assets.sh          copies + SHA-256 verifies the Apple binaries
      package-ipa.sh           unsigned .app -> .ipa
    patches/unicorn-ios.patch  iOS W^X fix for Unicorn
    VendorAssets/              the four Apple binaries, git-lfs
    .github/workflows/
      build-ios.yml            macOS runner: bridge -> app -> IPA -> release

---

## Building

### On GitHub Actions (recommended)

Push to `main` or open a pull request. The workflow runs two jobs:

1. **go-bridge** — unit tests, cross-compiles Unicorn for iOS arm64, binds the
   Go module into `SapBridge.framework` with gomobile.
2. **app** — downloads the framework, stages and verifies the Apple assets,
   builds an unsigned `.app`, packages it as `DLiPA-unsigned.ipa`, uploads it
   as an artifact. Tagged pushes also attach it to a release.

Run it manually from the Actions tab with **Run workflow**.

### Locally (macOS with Xcode)

    brew install ldid cmake xcodegen

    # 1. Unicorn for iOS
    ./scripts/build-unicorn-ios.sh

    # 2. bind the Go bridge
    cd sapbridge
    CGO_ENABLED=1 GOOS=ios GOARCH=arm64 gomobile bind \
      -target=ios -o ../app/DLiPA/Frameworks/SapBridge.framework .
    cd ..

    # 3. stage the assets
    ./scripts/stage-assets.sh

    # 4. generate the project and build unsigned
    cd app
    xcodegen generate
    xcodebuild -project DLiPA.xcodeproj -scheme DLiPA \
      -configuration Release -sdk iphoneos \
      -destination "generic/platform=iOS" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

    # 5. package
    ./scripts/package-ipa.sh build/Build/Products/Release-iphoneos/DLiPA.app DLiPA.ipa

## Installing

Download `DLiPA-unsigned.ipa` from the workflow run (or a release), then:

- **AltStore** — My Apps tab, tap +, choose the IPA, sign in with your Apple ID
- **Sideloadly** — drag the IPA in, sign in

Free Apple IDs get a 7-day certificate, so re-sign weekly. A paid developer
account lasts a year.

---

## Scope

This is a **functional core**, not a full UI recreation of DLiPA 1.4. It
implements sign-in, search, and the signed download path — the parts that
needed fixing. The original app's 100 Objective-C classes, 12 localisations,
CocoaHTTPServer install flow and SSZipArchive packaging are not reproduced;
the source was never published, only the compiled IPA.

## Acknowledgements

- [ipatool](https://github.com/majd/ipatool) by Majd Alfhaily — the SAP signing
  stack this project vendors, MIT licensed
- [DLiPA](https://github.com/AhmedBafkir/DLiPA) by Ahmed Bafkir — the original app
