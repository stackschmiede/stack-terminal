#!/usr/bin/env bash
# tier-0 für stack-terminal: config/wezterm.lua (platzhalter ersetzt) in der echten wezterm.exe.
#   schnell (default): config lädt ohne lua-fehler (pcall + dofile) und wezterm übernimmt sie
#                      (eigene maus-bindings in show-keys — show-keys allein endet auch bei
#                      kaputter config mit exit 0, wezterm fällt still auf die standard-config zurück)
#   --full:            zusätzlich open-uri-handler (tests/handler_test.lua), tab-state (tests/busy_test.lua),
#                      dateien des nutzungs-bilds (tests/render_test.lua) und selbstheilung der
#                      hintergrundbilder (tests/heal_test.lua)
# braucht windows-interop (wezterm.exe aus WSL) — im firejail-jail nicht vorhanden → rot mit meldung.
# wezterm-pfad überschreibbar: WEZTERM_EXE=/mnt/c/…/wezterm.exe · quell-config (mutationstests): STACK_TERMINAL_CFG
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${STACK_TERMINAL_CFG:-config/wezterm.lua}"
FULL=0
[ "${1:-}" = --full ] && FULL=1

W="${WEZTERM_EXE:-/mnt/c/Program Files/WezTerm/wezterm.exe}"
if [ ! -x "$W" ]; then
  echo "❌ wezterm.exe nicht gefunden: $W (WEZTERM_EXE setzen · im jail fehlt windows-interop)"
  exit 2
fi

T="$(mktemp -d "${TMPDIR:-/tmp}/stack-terminal-verify.XXXXXX")"
cleanup() {
  if [ -n "${VERIFY_KEEP:-}" ]; then echo "testordner bleibt: $T"; return; fi  # fehlersuche
  rm -f "$T"/* "$T"/.wezterm-claude-usage.* "$T"/.wezterm-bg-heal.*; rmdir "$T"
}
trap cleanup EXIT

CFG="$T/wezterm.lua"
# assets = testordner mit dem echten logo (heal_test stempelt es); pfad als lua-string (\ verdoppelt),
# für den sed-ersatztext noch einmal verdoppelt
cp config/assets/logo-wordmark.png "$T/"
ASSETS="$(wslpath -w "$T")"
ASSETS="${ASSETS//\\/\\\\}"
sed -e 's/{{WSL_USERNAME}}/user/g' -e 's/{{WSL_DISTRO}}/Ubuntu/g' \
    -e 's#{{PROJECTS_PATH}}#/home/user/projects#g' \
    -e "s#{{ASSETS_PATH}}#${ASSETS//\\/\\\\}#g" \
    "$SRC" > "$CFG"
if grep -n '{{' "$CFG"; then
  echo "❌ unersetzte platzhalter in $SRC"
  exit 1
fi

fail=0
# <name> <test.lua> → schreibt nach $T/<name>.out; extra env per WT_ED, weitere exportierte
# variablen über WT_WSLENV_EXTRA (":NAME/p…"). der test läuft über tests/run_test.lua (pcall):
# bricht er schon beim laden ab, steht der lua-fehler in <name>.out statt nirgends
run_lua() {
  local name="$1" lua="$2"
  WSLENV="WT_CFG/p:WT_OUT/p:WT_TEST/p:WT_ED${WT_WSLENV_EXTRA:-}" WT_CFG="$CFG" WT_OUT="$T/$name.out" \
    WT_TEST="$PWD/$lua" WT_ED="${WT_ED:-code}" \
    "$W" --config-file "$(wslpath -w "$PWD/tests/run_test.lua")" show-keys > "$T/$name.keys" 2> "$T/$name.err" || true
}
check_result() { # <name> → RESULT n/n ohne FAIL
  local name="$1" res
  res="$(grep -E '^RESULT ' "$T/$name.out" 2>/dev/null || true)"
  if [ -z "$res" ]; then
    echo "❌ $name: kein ergebnis (test-lua nicht geladen?)"; head -c 600 "$T/$name.err"; fail=1; return
  fi
  if grep -q '^FAIL' "$T/$name.out"; then
    echo "❌ $name: $res"; grep -A2 '^FAIL' "$T/$name.out" | cut -c1-600; fail=1; return
  fi
  local got want
  got="${res#RESULT }"; want="${got#*/}"; got="${got%/*}"
  if [ "$got" != "$want" ]; then echo "❌ $name: $res"; fail=1; else echo "✅ $name: $res"; fi
}

# 1) laden ohne lua-fehler
run_lua load tests/load_test.lua
if [ "$(head -1 "$T/load.out" 2>/dev/null)" = OK ]; then
  echo "✅ load: config/wezterm.lua lädt ohne fehler"
else
  echo "❌ load: $(head -3 "$T/load.out" 2>/dev/null || echo 'kein ergebnis')"; fail=1
fi

# 2) wezterm übernimmt die config (eigene maus-bindings statt standard)
"$W" --config-file "$(wslpath -w "$CFG")" show-keys > "$T/keys.out" 2> "$T/keys.err" || true
n_dbl="$(grep -cE 'Up \{ streak: 2, button: Left \} +-> +CompleteSelection\(Clipboard\)$' "$T/keys.out" || true)"
if grep -q '^Mouse: mouse_reporting$' "$T/keys.out" && [ "${n_dbl:-0}" -ge 2 ]; then
  echo "✅ show-keys: eigene maus-bindings aktiv (mouse_reporting, doppelklick = kopieren ×$n_dbl)"
else
  echo "❌ show-keys: eigene bindings fehlen — wezterm hat die config verworfen"; head -c 600 "$T/keys.err"; fail=1
fi

if [ "$FULL" = 1 ]; then
  # editor-name aus der geprüften config (template: code · eigene configs: was dort steht)
  WT_ED="$(sed -n "s/^local FILE_LINK_EDITOR = '\([^']*\)'.*/\1/p" "$CFG" | head -1)" \
    run_lua handler tests/handler_test.lua
  check_result handler
  run_lua busy tests/busy_test.lua
  check_result busy
  # bild-dateien landen in $T statt in %USERPROFILE%, cache = fixture des tests
  export WEZTERM_CLAUDE_USAGE_DIR="$T" WEZTERM_CLAUDE_USAGE_CACHE="$T/cu-cache.json"
  : > "$WEZTERM_CLAUDE_USAGE_CACHE"
  WT_WSLENV_EXTRA=":WEZTERM_CLAUDE_USAGE_DIR/p:WEZTERM_CLAUDE_USAGE_CACHE/p" run_lua render tests/render_test.lua
  check_result render
  # selbstheilung: eigenes log des tests statt des wezterm-logs
  export WEZTERM_BG_HEAL_LOG="$T/heal.log"
  : > "$WEZTERM_CLAUDE_USAGE_CACHE"
  WT_WSLENV_EXTRA=":WEZTERM_CLAUDE_USAGE_DIR/p:WEZTERM_CLAUDE_USAGE_CACHE/p:WEZTERM_BG_HEAL_LOG/p" run_lua heal tests/heal_test.lua
  unset WEZTERM_CLAUDE_USAGE_DIR WEZTERM_CLAUDE_USAGE_CACHE WEZTERM_BG_HEAL_LOG
  check_result heal
fi

[ "$fail" = 0 ] && echo "✅ stack-terminal verify ($([ "$FULL" = 1 ] && echo voll || echo schnell)): grün"
exit "$fail"
