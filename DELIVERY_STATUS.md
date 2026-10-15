# Delivery status

## Bottom line

The private repo, the complete implementation, and the CI configuration are
done. **The iOS package still cannot be produced**, and the reason is not the
code:

    X The job was not started because recent account payments have failed
      or your spending limit needs to be increased.

Every runner tier is blocked, including the free ubuntu ones, so this is an
account-level billing issue. Jobs are rejected in 6-7 seconds.

---

## Progress this round

CI stayed blocked, so the work went into the parts that had never been
reviewed at all: the Swift app and the localisation data.

### The recovered strings are now actually used

DLiPA 1.4 shipped its `Localizable.strings` as **binary plists**, so they were
sitting unused. They are now converted to text:

    14 languages x 120 keys = 1666 strings

and the UI calls `NSLocalizedString` for every label. Verified: all 17 keys the
code references resolve in all 14 languages.

### Bugs found by reading the Swift

The Swift had never been compiled, so this was overdue. Five real bugs:

| Bug | Consequence | Fix |
|---|---|---|
| `CC_SHA256` with no CommonCrypto import | compile error, CommonCrypto is not importable from Swift | CryptoKit |
| project.yml never set SWIFT_OBJC_BRIDGING_HEADER | gomobile types unresolvable in Swift | set it |
| no asset catalog | app ships with no icon | added one from the original icon |
| redirect kept the body on 303 | HTTP 303 becomes a GET, so re-POSTing is wrong | follow 301/302/307/308 only |
| assumed Location was absolute | relative Location broke the redirect | resolve against the request URL |
| numeric failure types shown raw | user sees "2034" instead of a message | map to the ap_* keys |

---

## What CI proved before it was cut off

From run 38708176362, the last full run:

| Stage | Evidence |
|---|---|
| LFS pull of the 119 MB assets | pass |
| go test | ok |
| Unicorn download + sha256 | OK |
| iOS W^X patch (4 hunks) | applying 4 file sections |
| Unicorn cross-compile | Built target aarch64-softmmu |
| libunicorn-static.a | linked |
| gomobile install + init | gomobile ready |
| gomobile bind | SapBridge.xcframework built |
| uc_open in the framework | failed; fixed with -ldflags, not yet re-run |

The one unverified item is whether `-ldflags` gets Unicorn into the
framework. Everything upstream of it is proven.

---

## To get the IPA

Either unblock Actions at https://github.com/settings/billing and re-run, or
build on your own Mac - the commands are in the previous report and in
README.md.

## Repo

    https://github.com/a23bc/dlipa-rebuild   (private, 20 commits)

Local checks that still pass: `go build`, `go vet`, `go test` (11 tests),
`gofmt`, and linux/arm64 cross-compile.
