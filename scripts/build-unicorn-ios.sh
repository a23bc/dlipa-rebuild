#!/bin/sh
# Cross-compile Unicorn 2.1.4 for iOS arm64 and stage the static library
# where the Go build can force-load it.
#
# IMPORTANT: the upstream ipatool tools/build-ios.sh passes -DUNICORN_ARCH=x86.
# That is wrong: the SAP guest is an arm64 Mach-O, so uc_open(UC_ARCH_ARM64)
# would fail at runtime. Valid values are
# x86;arm;aarch64;riscv;mips;sparc;m68k;ppc;s390x;tricore.
set -eu

UNICORN_VERSION=2.1.4
UNICORN_SHA256=ea8863f095a0136388694e5a6063afd9bb7650e30243dd6251af59c5ce5601f4
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT HUP INT TERM

echo "==> Unicorn $UNICORN_VERSION for iOS arm64 (arch=aarch64)"

curl -fL --retry 3 \
  "https://github.com/unicorn-engine/unicorn/archive/refs/tags/${UNICORN_VERSION}.tar.gz" \
  -o "$BUILD_DIR/unicorn.tar.gz"
echo "$UNICORN_SHA256  $BUILD_DIR/unicorn.tar.gz" | shasum -a 256 -c -
tar -xzf "$BUILD_DIR/unicorn.tar.gz" -C "$BUILD_DIR"

# iOS W^X: the JIT buffer is toggled between writable and executable instead of
# using RWX or MAP_JIT, neither of which a sandboxed process may use.
patch -d "$BUILD_DIR/unicorn-$UNICORN_VERSION" -p1 < "$ROOT/patches/unicorn-ios.patch"

# The patch targets src/qemu/... which matches the extracted layout.

SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)

SRC_DIR="$BUILD_DIR/unicorn-$UNICORN_VERSION/src"
cmake -S "$SRC_DIR" -B "$BUILD_DIR/build" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_C_FLAGS="-target arm64-apple-ios15.0" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DUNICORN_ARCH=aarch64 \
  -DUNICORN_BUILD_TESTS=OFF \
  -DUNICORN_INSTALL=OFF
cmake --build "$BUILD_DIR/build" --parallel "$(sysctl -n hw.ncpu)"

# With BUILD_SHARED_LIBS=OFF CMake renames the target to unicorn-static, so the
# archive lands as libunicorn-static.a.
ARCHIVE="$BUILD_DIR/build/libunicorn-static.a"
if [ ! -f "$ARCHIVE" ]; then
  ARCHIVE=$(find "$BUILD_DIR/build" -name "libunicorn*.a" | head -n 1)
fi
if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
  echo "::error::libunicorn archive was not produced" >&2
  exit 1
fi

mkdir -p "$ROOT/build/ios"
cp "$ARCHIVE" "$ROOT/build/ios/libunicorn.a"
echo "==> using $ARCHIVE"

# purego resolves the statically linked API through dlsym, so the symbols must
# be exported. The Go build adds these flags via CGO_LDFLAGS.
cat > "$ROOT/build/ios/unicorn.env" <<EOF
CGO_ENABLED=1
GOOS=ios
GOARCH=arm64
CGO_LDFLAGS=-Wl,-force_load,$ROOT/build/ios/libunicorn.a -Wl,-export_dynamic
EOF

echo "==> staged build/ios/libunicorn.a"
ls -la "$ROOT/build/ios"
