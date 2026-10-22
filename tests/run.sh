#!/usr/bin/env bash
# Syntax-checks every addon .lua file and runs tests/*_spec.lua with Lua 5.1
# (WoW 3.3.5a embeds Lua 5.1; LuaJIT is 5.1-compatible and fine for this).
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v lua5.1 >/dev/null 2>&1; then LUA=lua5.1
elif command -v luajit >/dev/null 2>&1; then LUA=luajit
elif command -v lua >/dev/null 2>&1 && lua -v 2>&1 | grep -q "Lua 5.1"; then LUA=lua
else
  echo "Need Lua 5.1: 'apt install lua5.1' (Linux) or 'brew install luajit' (macOS)" >&2
  exit 1
fi

echo "== syntax ($LUA)"
find . -name '*.lua' -not -path './tests/*' -not -path './.git/*' | sort | while read -r f; do
  "$LUA" -e "local ok, err = loadfile('$f'); if not ok then io.stderr:write(err .. '\n'); os.exit(1) end"
  echo "ok  $f"
done

status=0
for spec in tests/*_spec.lua; do
  echo "== $spec"
  "$LUA" "$spec" || status=1
done
if command -v python3 >/dev/null 2>&1; then
  echo "== tests/test_arena_tool.py"
  python3 tests/test_arena_tool.py 2>&1 | tail -3 || status=1
  python3 tests/test_arena_tool.py >/dev/null 2>&1 || status=1
else
  echo "(python3 not found: skipping tools/arena.py tests)"
fi
exit $status
