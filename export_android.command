#!/bin/zsh
set -eu
cd -- "${0:A:h}"
exec python3 tools/export_android.py "$@"
