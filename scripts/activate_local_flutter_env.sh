#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# activate_local_flutter_env.sh
# Helper to activate a writable local Flutter SDK for this project.
# Must be *sourced* to persist environment vars in your current shell:
#   source scripts/activate_local_flutter_env.sh [SDK_PATH]
# If SDK_PATH not provided, defaults to: $HOME/flutter-sdk
#
# Exports:
#   USE_LOCAL_FLUTTER=<resolved sdk path>
#   PATH=<sdk>/bin:$PATH (prepended)
# ---------------------------------------------------------------------------
set -euo pipefail

# Compatible with bash or zsh when sourced. Some shells (zsh) may not define BASH_SOURCE.
_SRC_FILE="${BASH_SOURCE[0]:-${(%):-%x}}" 2>/dev/null || _SRC_FILE="$0"
# In POSIX shells without BASH_SOURCE or zsh parameter, fallback to $0 (best effort).
if [ "${_SRC_FILE}" = "$0" ]; then
  echo "[WARN] This script should be *sourced* so that environment variables persist." >&2
  echo "       Use:  source scripts/activate_local_flutter_env.sh [SDK_PATH]" >&2
fi

SDK_PATH="${1:-$HOME/flutter-sdk}"

if [ ! -d "$SDK_PATH" ]; then
  echo "[ERROR] SDK path not found: $SDK_PATH" >&2
  return 2 2>/dev/null || exit 2
fi
if [ ! -x "$SDK_PATH/bin/flutter" ]; then
  echo "[ERROR] '$SDK_PATH/bin/flutter' missing (not a Flutter root)." >&2
  return 3 2>/dev/null || exit 3
fi

# Permission check
mkdir -p "$SDK_PATH/bin/cache" 2>/dev/null || true
if ! touch "$SDK_PATH/bin/cache/.perm_test" 2>/dev/null; then
  echo "[ERROR] No write permission on $SDK_PATH/bin/cache" >&2
  echo "        Fix: chown/chmod the directory or choose another path." >&2
  return 4 2>/dev/null || exit 4
fi

export USE_LOCAL_FLUTTER="$SDK_PATH"
case ":$PATH:" in
  *":$SDK_PATH/bin:"*) ;; # already present
  *) export PATH="$SDK_PATH/bin:$PATH";;
esac

echo "[OK] Activated local Flutter SDK: $USE_LOCAL_FLUTTER"
echo "[INFO] flutter: $(command -v flutter)"
flutter --version 2>/dev/null || echo "[WARN] flutter --version failed (check SDK)." >&2

echo "Next typical commands:\n  flutter pub get\n  flutter pub run build_runner build --delete-conflicting-outputs\n  flutter run -d web-server --web-port 3021\n"
