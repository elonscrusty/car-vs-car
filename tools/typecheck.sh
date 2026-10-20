#!/bin/bash
# Offline Luau type check (luau-lsp with the Roblox types) for the files you name:
#   tools/typecheck.sh src/client/TutorialClient.luau src/server/TutorialService.luau
# With no names it prints every error. The first run downloads luau-lsp and the Roblox type
# definitions into $TYPECHECK_DIR (default /tmp/cvc-typecheck). Needs rojo on PATH (rokit.toml).
# Some errors were there before your change (compare with a run on the base). CI does not run this.
set -euo pipefail
cd "$(dirname "$0")/.."
DIR="${TYPECHECK_DIR:-/tmp/cvc-typecheck}"
mkdir -p "$DIR"
if [ ! -x "$DIR/luau-lsp" ]; then
	curl -sSL -o "$DIR/luau-lsp.zip" \
		https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip
	(cd "$DIR" && unzip -oq luau-lsp.zip && chmod +x luau-lsp)
fi
if [ ! -s "$DIR/globalTypes.luau" ]; then
	curl -sSL -o "$DIR/globalTypes.luau" \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o "$DIR/sourcemap.json" >/dev/null
"$DIR/luau-lsp" analyze --definitions="$DIR/globalTypes.luau" --sourcemap="$DIR/sourcemap.json" \
	src >"$DIR/out.txt" 2>&1 || true
# keep only real type errors, with repo-relative paths
clean() { grep -v "Unknown require" | sed -E "s#$PWD/##"; }
if [ "$#" -eq 0 ]; then
	clean <"$DIR/out.txt"
else
	for f in "$@"; do
		echo "== $f"
		grep -F "/$f" "$DIR/out.txt" | clean || true
	done
fi
