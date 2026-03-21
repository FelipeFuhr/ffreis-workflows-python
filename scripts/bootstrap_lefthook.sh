#!/usr/bin/env sh
set -eu

LEFTHOOK_VERSION="${LEFTHOOK_VERSION:-1.7.10}"
BIN_DIR="${BIN_DIR:-.bin}"
BIN="$BIN_DIR/lefthook"

mkdir -p "$BIN_DIR"

if [ ! -x "$BIN" ]; then
  echo "Downloading lefthook v$LEFTHOOK_VERSION ..."

  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Linux)  OS=Linux ;;
    Darwin) OS=Darwin ;;
    *)
      echo "Unsupported OS: $OS" >&2
      exit 2
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64) ARCH=x86_64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *)
      echo "Unsupported arch: $ARCH" >&2
      exit 2
      ;;
  esac

  URL="https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_${OS}_${ARCH}"
  CHECKSUMS_URL="https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/checksums.txt"

  curl --fail --show-error --silent --location \
     --proto '=https' \
     --tlsv1.2 \
     "$URL" -o "$BIN"

  echo "Verifying checksum ..."
  CHECKSUMS_FILE="$(mktemp)"
  curl --fail --show-error --silent --location \
     --proto '=https' \
     --tlsv1.2 \
     "$CHECKSUMS_URL" -o "$CHECKSUMS_FILE"

  EXPECTED="$(grep "lefthook_${LEFTHOOK_VERSION}_${OS}_${ARCH}$" "$CHECKSUMS_FILE" | awk '{print $1}')"
  rm -f "$CHECKSUMS_FILE"

  if [ -z "$EXPECTED" ]; then
    echo "ERROR: Could not find checksum for lefthook_${LEFTHOOK_VERSION}_${OS}_${ARCH}" >&2
    rm -f "$BIN"
    exit 1
  fi

  if command -v sha256sum > /dev/null 2>&1; then
    ACTUAL="$(sha256sum "$BIN" | awk '{print $1}')"
  elif command -v shasum > /dev/null 2>&1; then
    ACTUAL="$(shasum -a 256 "$BIN" | awk '{print $1}')"
  else
    echo "ERROR: Neither sha256sum nor shasum found; cannot verify download." >&2
    rm -f "$BIN"
    exit 1
  fi

  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "ERROR: Checksum mismatch for $BIN (expected $EXPECTED, got $ACTUAL)" >&2
    rm -f "$BIN"
    exit 1
  fi

  echo "Checksum verified."
  chmod +x "$BIN"
fi

echo "Lefthook available at: $BIN"
