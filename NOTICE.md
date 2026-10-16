# Third-party components

This project builds on other people's work. Their licenses are reproduced or
summarised here; the components themselves remain under their own terms.

## ipatool - the SAP protocol implementation

    https://github.com/majd/ipatool
    Copyright (c) 2021 Majd Alfhaily
    MIT License

The two-leg sign-sap-setup handshake, the FairPlay kbsync blob, the
ent/download request shape and the CoreFP guest execution in
`sapbridge/internal/sap/` are a trimmed, vendored copy of the relevant parts
of ipatool v2. The iOS W^X patch for Unicorn comes from the same place.
Full text: https://opensource.org/licenses/MIT

## Unicorn CPU emulator

    https://github.com/unicorn-engine/unicorn
    Copyright (c) 2013-2021 Nguyen Anh Quynh and other contributors
    GNU GPL v2 (with a linking exception permitting static linking of the
    bundled qemu and glib sources)

Built for iOS arm64 by `scripts/build-unicorn-ios.sh` from the pinned 2.1.4
release and statically linked into the app. Nothing from the Unicorn source
is vendored into this repository; it is fetched at build time.

## Go dependencies

| Package | Version | License |
|---|---|---|
| github.com/blacktop/go-macho | v1.1.282 | MIT (blacktop) |
| github.com/ebitengine/purego | v0.10.2 | Apache 2.0 |
| howett.net/plist | v1.0.1 | BSD 2-Clause (Dustin L. Howett) |
| golang.org/x/mobile | latest | BSD 3-Clause (The Go Authors) |

## iOS app resources

The four Apple binaries in `VendorAssets/` (CoreFP, AppleMediaServices,
commerce, CoreFP.icxs) are Apple copyright, extracted from a macOS restore
image. They are included only because the signing protocol requires running
them, and are not redistributable on their own terms.

The app icon and the 14 `Localizable.strings` files in `app/DLiPA/` come
from the original DLiPA 1.4 application, whose repository
(https://github.com/AhmedBafkir/DLiPA) carries no source and states no
license. They are carried over so this build is a drop-in replacement, and
are replaced by originals if that becomes appropriate.

## Relationship to the original DLiPA

This is an independent rebuild, not a patch of the original. The original
ships only compiled artifacts, so every line here was written from the
protocol requirements and from ipatool as a reference implementation. The
bundle identifier is deliberately different
(`com.a23bc.dliparebuild`, not `com.ahmedbafkir.dlipa`) so the two apps
coexist rather than overwrite each other.
