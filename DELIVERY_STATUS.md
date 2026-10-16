# IPA rebuilt: own bundle id, real logging, iOS 15 floor

    DLiPA-unsigned.ipa    91.19 MB    arm64    iOS 15.0
    bundle id  com.a23bc.dliparebuild
    sha256     a9d8e98d1f0cff1ae8c5914564d8fbf77e6490ebeed7e0563929fb31e1483b83
    run        https://github.com/a23bc/dlipa-rebuild/actions/runs/38879672530

Read back out of the shipped Info.plist, not just the project file:

    CFBundleIdentifier          com.a23bc.dliparebuild
    MinimumOSVersion            15.0
    CFBundleShortVersionString  1.4.1
    CFBundleIconFiles           icon-152.png

## 1. Bundle id

`com.ahmedbafkir.dlipa` -> `com.a23bc.dliparebuild`.

A shared bundle id makes iOS treat two apps as one, so installing this
over the original would have replaced it, and vice versa. Now they coexist.

## 2. Logging

There was none. Everything used `print()`, which writes to stdout - and
nothing reads stdout once the app is not attached to a debugger. Every
diagnostic was invisible on a real device.

`AppLog` replaces it:

- `os.Logger` -> Console.app and
  `log stream --predicate 'subsystem == "com.a23bc.dliparebuild"'`
- a bounded 500-entry buffer the on-screen log view reads
- a Share button that exports the buffer as text, so a failure can be
  reported without a cable
- six categories: app, auth, sap, assets, network, download
- levels debug/info/warn/error; Release drops debug
- percent signs escaped, because os.Logger takes a format string and would
  otherwise truncate a URL at the first `%`

29 call sites at the points that explain failures:

    what the bag actually carried (SAP version, download endpoint)
    the authenticate URL chosen and the response
    every signed request status code
    403 with whether a signature was attached
    each redirect followed
    kbsync generated vs reused from cache, and its size
    each asset staged, with its byte count
    sign-in failures with their detail string

Zero `print()` remain.

## 3. iOS version

15.0 everywhere - project.yml, Info.plist, and the Unicorn cross-compile
flags. Unchanged, and now verified rather than assumed:

| API used | Requires |
|---|---|
| os.Logger | iOS 14 |
| async/await, CryptoKit | iOS 13 |
| ISO8601DateFormatter | iOS 10 |
| UIActivityViewController, ByteCountFormatter | iOS 6 |

Checked for APIs that would need newer: Observation, NavigationStack,
Charts, Gauge, the iOS 18 Tab syntax - none present. The floor is 14.0, so
your iOS 15 test device runs everything.

## One bug in the new code

`Logger.warn` does not exist; the method is `Logger.warning`. Caught by the
CI Swift compile. The level enum keeps `.warn` at the call site; only the
dispatch needed the real name.

## Also

The IPA dropped from 97.37 to 91.19 MB: the 6 MB packaging tarball that was
leaking into the bundle is now deleted after unpacking.

Go module still `go build`, `go vet`, `go test` (11 tests) and `gofmt` clean.
