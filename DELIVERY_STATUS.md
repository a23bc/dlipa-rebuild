# Delivery status

## Bottom line

**The iOS package still cannot be produced.** GitHub Actions rejects every job
in 6-8 seconds:

    X The job was not started because recent account payments have failed
      or your spending limit needs to be increased.

This is account-level billing, not a code problem. All runner tiers are
blocked, including the free ubuntu ones.

---

## This round: closing the last unverified gap

The only item CI never got to confirm was whether Unicorn actually ends up
inside the framework. Relying on `gomobile -ldflags` alone is fragile: if the
flag is dropped the archive is silently absent, and the failure appears only
as a `Dlsym` error on a device, long after CI is green.

So there are now two independent mechanisms:

1. `link_ios.go` carries a cgo preamble with undefined `uc_*` references, so
   the linker **must** resolve them from the archive.
2. `-ldflags` force-loads the whole archive and exports its symbols for
   `purego.Dlsym`.

A dropped flag now degrades instead of breaking.

### Verified

File selection is mutually exclusive by build tag, confirmed with `go list`:

    windows cgo=0 -> link_stub.go   (no-op)
    linux   cgo=0 -> link_stub.go   (no-op)
    ios     cgo=1 -> link_ios.go    (CgoFiles)

`ForceLink` is called from an `init` in the machine package so it cannot be
dropped as dead code, and it is defined exactly once per platform.

    go build   = 0      go vet = 0
    go test    = ok     gofmt = clean
    linux/arm64 cross-compile = 0

### Bug I introduced and caught

While rewriting the bind step I left a YAML line continuation that made
`gomobile bind ... \` swallow the next line, and dropped a step's
indentation. `yaml.safe_load` caught it: "expected <block end>, but found
-'". Fixed and re-validated: 27 steps across 3 jobs.

This is exactly why the workflow is now parsed with a real YAML parser before
every push.

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
| uc_open in framework | failed then; two mechanisms now |

---

## To get the IPA

1. https://github.com/settings/billing - fix the payment method or raise the
   Actions spending limit from $0
2. Re-run the workflow

Or build locally on a Mac; the commands are in README.md.

    https://github.com/a23bc/dlipa-rebuild   (private, 22 commits)
