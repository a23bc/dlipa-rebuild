# Sealed and identified: the last identity mismatch

    DLiPA-c51cf9d3.ipa    85.45 MB
    sha256  94c7cc48f8393c923c79dbd0f61b538d03022d36aac937f19a467024124ccb2d
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/39020289028

## What the install log revealed

TrollStore extracted a different set of entitlements from our binary than
from the original: only `get-task-allow`, where the original also yielded
`application-identifier`, `team-identifier` and `keychain-access-groups`.

## The cause
Parsing the CodeDirectory of both binaries:

    original identifier   com.ahmedbafkir.dlipa
    ours identifier       DLiPA

ldid defaults the CodeDirectory identifier to the executable basename. Ours
said `DLiPA`; the original carries the full bundle id. MobileInstallation
reads that field to type the bundle, and a bare filename is not a valid
identity - hence `ApplicationType = System`.

`-I` overrides it. Two details worth recording because both cost a build:

- ldid takes the value from `argv + 2`, so it must be attached: `-I<id>`.
  `-I com.a23bc.dliparebuild` left the identifier empty and then treated the
  bundle id as a file path.
- Only the procursus build of ldid still has `-S`, and only it documents
  `-I` alongside it.

## Verified in the shipped IPA

    CodeDirectory identifier   com.a23bc.dliparebuild   (was: DLiPA)
    _CodeSignature/CodeResources 10234 bytes
    LC_CODE_SIGNATURE            present
    bundle root                  unchanged and matching the original

## What still differs, and cannot be fixed here

The original carries a CMS signature in slot `0x10000` - a real signature
from an Apple Development certificate. Ours has an alternate CodeDirectory
in that slot instead, because producing a CMS signature needs a certificate
chain and there is no developer account here.

TrollStore exists precisely to install Apple-signed apps by bypassing that,
and it re-signs on install regardless, so this is expected rather than
blocking. Worth knowing in case the CoreTrust bypass behaves differently
for a binary that never had one.
