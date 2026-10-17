# Sealed: the bundle now matches the one that installs

    DLiPA-e21fe5a7.ipa    85.45 MB
    sha256  034940478a5ef78d0599a6e00a0b8c6cb935daa98f8fcac0a126d1a7b97dfb69
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/39018770540

## What was missing

The confirmation that the original DLiPA 1.4 installs on this device made it
the reference. Comparing the two bundles field by field found two things it
has and every build of ours lacked:

    _CodeSignature/CodeResources    present -> absent
    LC_CODE_SIGNATURE in the Mach-O present -> absent

CodeResources is the sealing manifest - a plist listing every resource with its
SHA-1 and SHA-256, plus the omission rules. Without it MobileInstallation
treats the bundle as unsealed, types it System, and fails registration with
error 181. That also explains the `MissingSINF = 0` that had been nagging: iOS
reports no missing signature container because it is looking for the sealing
artefacts it never found.

This is why comparing against `ipa-downloader` sent me down the wrong path.
It has neither and still installs, so I concluded signing was irrelevant. It
was the wrong reference - the original DLiPA was the right one.

## How it is produced

`codesign` cannot do it here: it validates the whole bundle and rejects one
resource after another, first `.lproj`, then the icons, and there is no
certificate to satisfy it with. Homebrew `ldid` 2.1.5 dropped the `-S` flag it
would need. So both artefacts are produced directly:

- `scripts/make-coderesources.py` writes `_CodeSignature/CodeResources`
- `ldid` from opa334 at tag `v2.1.5-procursus5`, the build that kept `-S`,
  writes `LC_CODE_SIGNATURE` into the executable

## Verified in the shipped IPA

    _CodeSignature/CodeResources   10234 bytes
    LC_CODE_SIGNATURE             present, same as the original
    bundle root                   AppIcon x2, Assets.car, DLiPA, Info.plist, PkgInfo

And the sealing manifest itself, compared against the original:

    keys, rules, rules2          identical
    files 27 vs 26               ours add the 4 SAP assets and CoreFP.icxs
                                  under Resources/, the original has
                                  embedded.mobileprovision and the files we
                                  correctly do not carry

The SHA-256 values were checked against the files when generated: 0 mismatches.
