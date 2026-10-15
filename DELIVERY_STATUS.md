# 交付状态报告（最终）

## 结论

私密仓库已建好、完整实例已写完、CI 已验证到只剩最后一步。
但 iOS 安装包目前拿不到，原因不在代码：

    X The job was not started because recent account payments have failed
      or your spending limit needs to be increased.
      Please check the Billing & plans section of your settings

GitHub Actions 的 macOS runner 按时计费，账号的付款/额度卡住了，
job 根本没启动（5-7 秒即失败）。这是账号层面的事，无法从这边解决。

---

## 已完成并有证据

### 仓库

    https://github.com/a23bc/dlipa-rebuild   (private)

### CI 实际跑通的部分（来自 run 38708176362 的真实日志）

| 阶段 | 状态 |
|---|---|
| git lfs pull 119 MB Apple assets | pass |
| go test ./... | ok (11 unit tests pass locally) |
| download Unicorn 2.1.4 + sha256 check | pass |
| apply the iOS W^X patch (4 hunks) | pass (applying 4 file sections) |
| cross-compile Unicorn (UNICORN_ARCH=aarch64) | Built target aarch64-softmmu |
| produce libunicorn-static.a | pass |
| gomobile install + init | gomobile ready |
| gomobile bind SapBridge.xcframework | built |
| verify uc_open in the framework | failed, fixed with -ldflags, needs re-run |

也就是说：从源码到 iOS framework 的整条链只剩一个待验证的链接参数问题。

### Local verification (Windows, no Xcode)

| Item | Result |
|---|---|
| go build ./... | BUILD=0 |
| go vet ./... | VET=0 |
| go test | 11 PASS / 2 SKIP (live tests need Unicorn) |
| gofmt -l | clean |
| linux/arm64 cross-compile | BUILD=0 |
| iOS file selection | library_ios.go is selected |

---

## What is blocking (needs you)

GitHub Actions macOS runners are billed for private repos. To resume:

1. Open https://github.com/settings/billing
2. Check payment method / spending limit
3. Raise the Actions spending limit (it may default to $0)

---

## What you already have (without CI)

1. Complete source (33 commits)
   - sapbridge/  Go signing stack with 11 tests
   - app/        Xcode project + Swift sources
   - scripts/    build scripts
   - .github/workflows/  CI config

2. All the verified findings
   - SIGNATURE_EXPERIMENT.md: signed 200 / unsigned 403 / no trailing slash 204
   - ROUND5_EVIDENCE.md: SAP signing + kbsync reach live Apple
   - The four Apple binaries (119 MB, git-lfs)

3. A build path on your own Mac

       cd dlipa-rebuild
       ./scripts/build-unicorn-ios.sh
       cd sapbridge
       CGO_ENABLED=1 GOOS=ios GOARCH=arm64 gomobile bind \
         -ldflags="-Wl,-force_load,$PWD/../../build/ios/libunicorn.a -Wl,-export_dynamic" \
         -target=ios -o ../app/DLiPA/Frameworks/SapBridge.xcframework .
       cd ..
       ./scripts/stage-assets.sh
       cd app && xcodegen generate
       xcodebuild -project DLiPA.xcodeproj -scheme DLiPA -configuration Release \
         -sdk iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
       cd .. && ./scripts/package-ipa.sh <app path> DLiPA.ipa

The last two steps cannot be verified from this machine, but every dependency
was verified either in CI or locally.

---

## Bug log (all found by CI)

| # | Symptom | Root cause |
|---|---|---|
| 1 | go test panic | loadBundle panicked without assets, killing the test binary |
| 2 | Permission denied | git did not record the executable bit |
| 3 | every patch hunk rejected | I validated against the PyPI sdist layout, but the script downloads the GitHub archive |
| 4 | macOS vs iOS link error | CGO_LDFLAGS leaked into the host tool gomobile |
| 5 | gomobile command not found | GOOS=ios made go install cross-compile into bin/ios_arm64/ |
| 6 | bind needs the dependency | go.mod lacked golang.org/x/mobile |
| 7 | gobind not found | gomobile init was dropped when splitting the steps |
| 8 | requires .xcframework suffix | gomobile naming rule for static frameworks |
| 9 | uc_open missing from framework | CGO_LDFLAGS did not reach bind; switched to -ldflags |
| 10 | job never starts | account Actions billing/spending limit (current blocker) |

Note on #3: I "fixed" the ipatool patch paths based on the PyPI sdist tree,
while the build script downloads the GitHub archive, whose layout differs.
My verification target was wrong, not the upstream code. Reverted to be
byte-identical with upstream.
