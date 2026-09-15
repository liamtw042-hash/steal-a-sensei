#!/usr/bin/env bash
# Same as check.ps1 but for Git Bash. Usage: scripts/check.sh [--fix]
set -euo pipefail
export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.."
[ -d Packages ] || wally install
rojo sourcemap default.project.json -o sourcemap.json
[ "${1:-}" = "--fix" ] && stylua src
luau-lsp analyze --definitions=tools/globalTypes.d.luau --sourcemap=sourcemap.json --settings=.luau-lsp.json --ignore "**/_Index/**" --ignore "Packages/**" --ignore "ServerPackages/**" src
stylua --check src
echo "OK: types, lint and formatting all pass"
