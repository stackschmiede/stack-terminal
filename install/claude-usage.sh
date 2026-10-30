#!/usr/bin/env bash
# TerminalStack — claude-usage.sh (Stackschmiede · https://stackschmiede.de)
#
# poller für die claude-abo-nutzung (5h-fenster · wochen-kontingent · modell-fenster).
# läuft in WSL (wezterm startet ihn über wsl.exe), liest den oauth-token aus
# <config-dir>/.credentials.json und schreibt NUR prozente + reset-zeiten als cache-json.
# die wezterm-config liest ausschließlich diesen cache — der token bleibt in WSL.
#
# aufruf:
#   bash claude-usage.sh --out <datei> [--account <label>=<dir>]... [--ttl <s>] [--now <epoch>]
#     --out      cache-datei (windows-pfad `C:\…` oder wsl-pfad; windows-pfade via wslpath)
#     --account  label=claude-config-dir in WSL (mehrfach; leeres label: '=~/.claude')
#     --ttl      nichts tun, wenn der cache jünger als <s> sekunden ist (default 0)
#     --now      epoch-sekunden des aufrufers (windows-uhr) — sonst `date +%s`
#
# cache-format (v1):
#   { v, fetched_at, accounts: [ { label, error, http, updated_at,
#       rows: [ { kind, label, pct, resets_at (epoch), severity, active } ] } ] }
#   kind: session (5h) · weekly_all (7d) · weekly_scoped (modell/surface, label = display_name)
#   error: null | login | no-config | no-token | net | parse | http <code> | jq fehlt
#   bei fehlern bleiben die alten rows des accounts erhalten (updated_at = letzter erfolg)
#
# sicherheit: token per curl `--config -` über stdin (nie argv, env oder log) · kein
# refresh-token-gebrauch (401 → "login", claude code erneuert den token selbst) · stderr
# nur http-status + fehlerklasse · 1 request pro account und aufruf
#
# exit: 0 cache geschrieben / ttl-skip · 2 argument-/schreibfehler

set -u

ENDPOINT='https://api.anthropic.com/api/oauth/usage'
OUT=''
TTL=0
NOW=''
ACCOUNTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --out)     OUT=${2-};            shift 2 ;;
    --account) ACCOUNTS+=("${2-}");  shift 2 ;;
    --ttl)     TTL=${2-0};           shift 2 ;;
    --now)     NOW=${2-};            shift 2 ;;
    -h|--help) sed -n '2,24p' "$0" >&2; exit 0 ;;
    *) echo "claude-usage: unbekanntes argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || { echo "claude-usage: --out fehlt" >&2; exit 2; }
[ "${#ACCOUNTS[@]}" -gt 0 ] || ACCOUNTS=('=~/.claude')

case "$NOW" in ''|*[!0-9]*) NOW=$(date +%s) ;; esac
case "$TTL" in ''|*[!0-9]*) TTL=0 ;; esac

# zielpfad: windows-pfad → wsl-pfad
case "$OUT" in
  [A-Za-z]:[\\/]*) OUT=$(wslpath -u "$OUT") || { echo "claude-usage: wslpath fehlgeschlagen" >&2; exit 2; } ;;
esac
OUT_DIR=$(dirname -- "$OUT")
[ -d "$OUT_DIR" ] || { echo "claude-usage: zielordner fehlt: $OUT_DIR" >&2; exit 2; }

# atomar schreiben: tmp im zielordner + mv
write_cache() {  # $1 = json-text
  local tmp
  tmp=$(mktemp "$OUT_DIR/.claude-usage.XXXXXX") || return 1
  printf '%s\n' "$1" > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$OUT" && return 0
  rm -f "$tmp"
  return 1
}

# abhängigkeiten: ohne jq/curl trotzdem einen cache mit fehlerklasse schreiben (statusleiste zeigt ihn)
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  missing='jq fehlt'; command -v jq >/dev/null 2>&1 && missing='curl fehlt'
  accs=''
  for spec in "${ACCOUNTS[@]}"; do
    label=${spec%%=*}; [ "$spec" = "$label" ] && label=''
    label=$(printf '%s' "$label" | tr -cd 'A-Za-z0-9 ._-')
    accs="$accs${accs:+,}{\"label\":\"$label\",\"error\":\"$missing\",\"http\":0,\"updated_at\":null,\"rows\":[]}"
  done
  write_cache "{\"v\":1,\"fetched_at\":$NOW,\"accounts\":[$accs]}" || exit 2
  echo "claude-usage: $missing (sudo apt install jq curl)" >&2
  exit 0
fi

# ttl: cache frisch → nichts tun (zweite wezterm-instanz / doppel-spawn)
if [ "$TTL" -gt 0 ] && [ -s "$OUT" ]; then
  last=$(jq -r '.fetched_at // 0' "$OUT" 2>/dev/null) || last=0
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  age=$((NOW - last))
  if [ "$age" -ge 0 ] && [ "$age" -lt "$TTL" ]; then exit 0; fi
fi

OLD='{}'
if [ -s "$OUT" ]; then OLD=$(jq -c '.' "$OUT" 2>/dev/null) || OLD='{}'; fi

TMPD=$(mktemp -d) || exit 2
trap 'rm -rf "$TMPD"' EXIT

# response → rows (server-format `limits[]`, fallback legacy-keys five_hour/seven_day/…)
JQ_ROWS='
def iso2epoch:
  if type != "string" then null else
    (capture("^(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<tz>Z|[+-][0-9]{2}:[0-9]{2})?$") // null) as $m
    | if $m == null then null else
        (($m.d + "Z") | fromdateiso8601) as $base
        | ($m.tz // "Z") as $tz
        | if $tz == "Z" then $base
          else $base - (if $tz[0:1] == "-" then -1 else 1 end) * (($tz[1:3] | tonumber) * 3600 + ($tz[4:6] | tonumber) * 60)
          end
      end
  end;
def pct: ((.percent // .utilization // 0) | tonumber | floor);
def sev($p): (.severity // (if $p >= 90 then "critical" elif $p >= 75 then "warning" else "normal" end));
def row_label:
  if .kind == "session" then "5h"
  elif .kind == "weekly_all" then "7d"
  elif .kind == "weekly_scoped" then (.scope.model.display_name // .scope.surface.display_name // "scoped")
  else (.kind // "?") end;
. as $root
| if (.limits | type) == "array" and (.limits | length) > 0 then
    [ .limits[] | pct as $p
      | { kind: (.kind // "?"), label: row_label, pct: $p, resets_at: (.resets_at | iso2epoch),
          severity: sev($p), active: (.is_active == true) } ]
  else
    [ { k: "five_hour",        kind: "session",       label: "5h"     },
      { k: "seven_day",        kind: "weekly_all",    label: "7d"     },
      { k: "seven_day_opus",   kind: "weekly_scoped", label: "Opus"   },
      { k: "seven_day_sonnet", kind: "weekly_scoped", label: "Sonnet" } ]
    | map(. as $m | $root[$m.k] | select(type == "object") | pct as $p
      | { kind: $m.kind, label: $m.label, pct: $p, resets_at: (.resets_at | iso2epoch),
          severity: sev($p), active: false })
  end
'

ACC_JSON='[]'
for spec in "${ACCOUNTS[@]}"; do
  label=${spec%%=*}; dir=${spec#*=}
  if [ "$spec" = "$label" ]; then dir=$spec; label=''; fi
  case "$dir" in '~') dir=$HOME ;; '~/'*) dir="$HOME/${dir#\~/}" ;; esac
  cred="$dir/.credentials.json"
  body="$TMPD/body"; : > "$body"
  err=''; http=0; rows=''

  if [ ! -r "$cred" ]; then
    err='no-config'
  else
    tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred" 2>/dev/null) || tok=''
    exp=$(jq -r '(.claudeAiOauth.expiresAt // 0) | floor' "$cred" 2>/dev/null) || exp=0
    case "$exp" in ''|*[!0-9]*) exp=0 ;; esac
    if [ -z "$tok" ]; then
      err='no-token'
    elif [ "$exp" -gt 0 ] && [ $((exp / 1000)) -le "$(date +%s)" ]; then
      err='login'   # access-token abgelaufen — claude code erneuert ihn beim nächsten start
    else
      # token NUR über stdin (curl-config) — nie in argv/env
      http=$(printf 'header = "Authorization: Bearer %s"\n' "$tok" | curl -sS --config - \
        --max-time 10 --retry 0 \
        -H 'anthropic-beta: oauth-2025-04-20' -H 'Accept: application/json' \
        -o "$body" -w '%{http_code}' "$ENDPOINT" 2>>"$TMPD/curl.err") || true
      tok=''
      case "$http" in ''|*[!0-9]*) http=0 ;; esac
      case "$http" in
        200)     rows=$(jq -c "$JQ_ROWS" "$body" 2>/dev/null) && [ -n "$rows" ] || { err='parse'; rows=''; } ;;
        401|403) err='login' ;;
        0|000)   err='net' ;;
        *)       err="http $http" ;;
      esac
    fi
  fi

  if [ -n "$err" ]; then
    echo "claude-usage: ${label:-default}: http=$http error=$err" >&2
    # alte rows dieses accounts behalten, fehler markieren
    acc=$(jq -c --arg l "$label" --arg e "$err" --argjson h "$http" '
      ((.accounts // []) | map(select(.label == $l)) | .[0] // {})
      | { label: $l, error: $e, http: $h, updated_at: (.updated_at // null), rows: (.rows // []) }' <<<"$OLD")
  else
    acc=$(jq -nc --arg l "$label" --argjson now "$NOW" --argjson rows "$rows" \
      '{ label: $l, error: null, http: 200, updated_at: $now, rows: $rows }')
  fi
  ACC_JSON=$(jq -c --argjson a "$acc" '. + [$a]' <<<"$ACC_JSON")
done

write_cache "$(jq -nc --argjson now "$NOW" --argjson accounts "$ACC_JSON" \
  '{ v: 1, fetched_at: $now, accounts: $accounts }')" || { echo "claude-usage: cache-schreiben fehlgeschlagen: $OUT" >&2; exit 2; }
exit 0
