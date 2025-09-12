#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# use_local_flutter.sh
# Switch project to a user-space Flutter SDK (writeable) instead of a protected
# Homebrew / system install that blocks cache updates.
#
# Usage:
#   scripts/use_local_flutter.sh <flutter_sdk_path> [--persist]
# Example:
#   git clone https://github.com/flutter/flutter.git "$HOME/flutter-sdk"
#   scripts/use_local_flutter.sh "$HOME/flutter-sdk" --persist
# -----------------------------------------------------------------------------
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <flutter_sdk_path> [--persist]" >&2
  exit 1
fi

SDK_PATH="$1"
PERSIST=false
if [[ $# -ge 2 && "$2" == "--persist" ]]; then
  PERSIST=true
fi

if [[ ! -d "$SDK_PATH" ]]; then
  echo "[ERROR] Directory not found: $SDK_PATH" >&2
  exit 2
fi
if [[ ! -x "$SDK_PATH/bin/flutter" ]]; then
  echo "[ERROR] '$SDK_PATH/bin/flutter' not found or not executable." >&2
  echo "        Ensure you pointed to the Flutter root (contains bin/flutter)." >&2
  exit 3
fi

mkdir -p "$SDK_PATH/bin/cache" 2>/dev/null || true
if ! touch "$SDK_PATH/bin/cache/.perm_test" 2>/dev/null; then
  echo "[ERROR] Cannot write to $SDK_PATH/bin/cache (permission denied)." >&2
  echo "        Fix with chown/chmod or choose a path inside your HOME." >&2
  exit 4
fi

export USE_LOCAL_FLUTTER="$SDK_PATH"
export PATH="$SDK_PATH/bin:$PATH"
echo "[OK] Using local Flutter SDK: $SDK_PATH" >&2
flutter --version || echo "[WARN] 'flutter --version' failed. Check SDK integrity." >&2

echo "USE_LOCAL_FLUTTER=$USE_LOCAL_FLUTTER"
which flutter

if $PERSIST; then
  RC_FILE=""
  if [[ -f "$HOME/.zshrc" ]]; then
    RC_FILE="$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    RC_FILE="$HOME/.bashrc"
  else
    RC_FILE="$HOME/.bashrc"; touch "$RC_FILE"
  fi
  {
    echo "";
    echo "# Added by use_local_flutter.sh on $(date)";
    echo "export USE_LOCAL_FLUTTER=\"$SDK_PATH\"";
    echo "export PATH=\"$SDK_PATH/bin:\$PATH\"";
  } >> "$RC_FILE"
  echo "[OK] Persisted environment to $RC_FILE" >&2
  echo "    Open a new shell OR: source $RC_FILE" >&2
fi

cat <<MSG
Next steps:
  1. (Optional) source your shell rc if you used --persist.
  2. Run:  ./jive-manager.sh restart web
     or:   (inside jive-flutter) flutter pub upgrade --major-versions && flutter run -d web-server --web-port 3021
MSG
