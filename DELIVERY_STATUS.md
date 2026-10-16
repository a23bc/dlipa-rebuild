# Error 181: the embedded framework was the cause

    DLiPA-7ada1800.ipa    91.53 MB
    sha256  3e914da1aa0e93e82acc60f3258fd7a526c08efe07316c86745cb9a4cb44a033
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/38891702142

## Five attempts, same failure

Every attempt failed with error 181 and `ApplicationType = System`, while
ldid and the CoreTrust bypass both succeeded each time. The app Info.plist was
matched to the original key by key, and the framework plist was fixed, and
neither changed anything. So the remaining difference had to be structural.

## What it was

We embedded `SapBridge.framework`. The original DLiPA embeds nothing - it is a
single executable. MobileInstallation has to validate every nested bundle
during registration, and that is what it was rejecting.

The framework turned out not to be needed at all. Checking the app binary:

    SapbridgeSerialNumber     present
    SapbridgeKBSync           present
    SapbridgeNew              present
    SapbridgeSetBundleDir     present
    SapbridgeGuidFromHardware present
    uc_open                   present
    uc_emu_start              present

Everything is already in the app binary, because the link force-loads the
archives. The framework was a 32 KB shim carrying no code of its own.

## What changed

- Removed the framework dependency from project.yml
- The bridge job now ships the gomobile archive itself instead of unpacking a
  framework, and `OTHER_LDFLAGS` force-loads both it and libunicorn.a
- The C declarations moved into the bridging header, with the nullability taken
  from the generated header rather than written from memory

## Verified in the shipped artifact

    Frameworks/ entries              none
    install-critical keys             9/9 identical to the original
    Assets.car                        IDENTICAL
    AppIcon60x60@2x.png               IDENTICAL
    AppIcon76x76@2x~ipad.png          IDENTICAL
    PkgInfo                           IDENTICAL
    bundle id                         com.a23bc.dliparebuild
    minimum iOS                       15.0

The bundle is now the same shape as the original: one executable, no nested
bundles.

## Two self-inflicted bugs on the way

Both caught by the CI build, both worth recording:

1. Removing the dependency left `dependencies:` empty, and XcodeGen rejects
   that: "Decoding failed at dependencies: Incorrect type". The key has to be
   omitted, not emptied.

2. The C declarations I wrote for the bridging header had the wrong
   nullability on `SapbridgeNew` and `SapbridgeKBSync` - both return optional,
   and the guard-let call sites then failed to compile. I had written them
   from memory instead of from the generated header that was already on disk.

That second one is the same mistake as an earlier round: guessing an API
shape when the real one is available to read. It cost a build cycle.
