#!/usr/bin/env bash
# Regenerates roblox.d.luau from the latest luau-lsp Roblox definitions,
# trimmed to the classes/enums this project uses (the WASM analyzer has a
# complexity limit that the full file exceeds).
set -euo pipefail
cd "$(dirname "$0")"
curl -sSfL -o /tmp/globalTypes.None.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau
python3 reduce_defs.py /tmp/globalTypes.None.d.luau roblox.d.luau keep_classes.txt keep_enums.txt
