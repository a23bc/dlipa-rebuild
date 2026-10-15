# Delivery status

## Bottom line

**The iOS package still cannot be produced.** GitHub Actions rejects every
job in 6-8 seconds:

    X The job was not started because recent account payments have failed
      or your spending limit needs to be increased.

Account-level billing, not a code problem. All runner tiers are blocked.

---

## This round: two real bugs in the never-reviewed paths

### 1. 119 MB copy on the main thread

AssetStaging.stageIfNeeded() was called directly from
didFinishLaunchingWithOptions, so launch would stall for as long as it takes
to copy 119 MB, and setBundleDir was called even when some files had failed
to copy. Sign-in then ran against assets that were not all there.

Now: runs on a utility queue, reports progress in ten-percent buckets, sets
the bundle directory only after every file is present, and signIn guards on
isReady.

### 2. kbsync regenerated on every download

Every download spun up the Unicorn guest and the Apple binaries again, even
though a blob is stable for a given account and device.

Now cached per account and device, and dropped when Apple rejects a
download with 2034, 2042 or 1008 so the next attempt regenerates it.

---

## Verification

    go build = 0      go vet = 0
    go test  = 11 PASS / 2 SKIP
    gofmt    = clean
    linux/arm64 cross-compile = 0
    iOS file selection: CgoFiles=[link_ios.go]

    all 9 Swift files balance
    11 localisation keys resolve in all 14 languages

Repo: private, 24 commits, clean tree.

---

## What CI already proved (run 38708176362)

| Stage | Evidence |
|---|---|
| LFS pull of 119 MB assets | pass |
| go test | ok |
| Unicorn sha256 | OK |
| iOS W^X patch, 4 hunks | applying 4 file sections |
| Unicorn cross-compile | Built target aarch64-softmmu |
| libunicorn-static.a | linked |
| gomobile install + init | gomobile ready |
| gomobile bind | SapBridge.xcframework built |
| uc_open in framework | unverified; two link mechanisms now |

---

## To get the IPA

1. https://github.com/settings/billing - fix the payment method or raise the
   Actions spending limit from $0
2. Re-run the workflow

Or build locally on a Mac; see README.md.

    https://github.com/a23bc/dlipa-rebuild
