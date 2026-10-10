#!/bin/bash

# Shared constants and helpers for the Hongguo install/launch/remove scripts.
# Sourced, not executed.
#
# Hongguo runs 100% NATIVELY on Linux -- no Wine, no Proton. The Windows
# "setup.exe" is just an NSIS self-extracting archive: install-hongguo.sh unpacks
# it with 7z to obtain the app's Python backend + Java signer jar (discarding the
# bundled Windows python/ and jre/). Everything then runs on a native Python venv
# + the host JVM + a native browser. So there is NO Wine prefix; all state lives
# under HG_HOME.

# App home: extracted backend, the native Python venv, and runtime data.
HG_HOME="$HOME/.local/share/hongguo-native"
HG_BACKEND="$HG_HOME/backend"      # unpacked app code (server.py, sign/, frida/, ...)
HG_VENV="$HG_HOME/venv"            # native Python 3.11 venv

# Echo the backend directory (the one holding server.py / desktop_bootstrap.py)
# if the app has been extracted, else empty.
find_backend_dir() {
  [[ -f "$HG_BACKEND/server.py" ]] && printf '%s' "$HG_BACKEND"
}
