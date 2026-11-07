#!/usr/bin/env bash
# Supply About's build revision without replacing explicit Flutter defines.

set -eu

BUILD_DART_DEFINES="${1:-}"

# Check if GIT_COMMIT is already present
if [ -n "$BUILD_DART_DEFINES" ]; then
  OLD_IFS="$IFS"
  IFS=','
  for encoded_define in $BUILD_DART_DEFINES; do
    decoded_define="$(printf '%s' "$encoded_define" | base64 -d 2>/dev/null || printf '%s' "$encoded_define" | base64 --decode 2>/dev/null || true)"
    case "$decoded_define" in
      GIT_COMMIT=*)
        IFS="$OLD_IFS"
        printf '%s\n' "$BUILD_DART_DEFINES"
        exit 0
        ;;
    esac
  done
  IFS="$OLD_IFS"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_GIT_COMMIT="$(git -C "$SCRIPT_DIR/.." rev-parse --short=8 HEAD 2>/dev/null || true)"
case "$BUILD_GIT_COMMIT" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
    encoded_commit="$(printf 'GIT_COMMIT=%s' "$BUILD_GIT_COMMIT" | base64 | tr -d '\r\n')"
    if [ -n "$BUILD_DART_DEFINES" ]; then
      BUILD_DART_DEFINES="${BUILD_DART_DEFINES},${encoded_commit}"
    else
      BUILD_DART_DEFINES="$encoded_commit"
    fi
    ;;
esac

printf '%s\n' "$BUILD_DART_DEFINES"
