#!/bin/zsh
cd -- "${0:A:h}"
./tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
