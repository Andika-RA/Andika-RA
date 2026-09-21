#!/usr/bin/env bash
# verify-profile.sh — RED acceptance suite for profile README (TDD Red phase, Wave2).
# Usage: ./verify-profile.sh [README_PATH]   (default: ./README.md)
# Exit 0 = ALL gates pass (GREEN). Exit 1 = at least one gate FAILs (RED).
# Every gate prints a named PASS/FAIL line. FAIL log should be saved, e.g.:
#   ./verify-profile.sh > red-baseline.log 2>&1
set -u

README="${1:-README.md}"
FAIL=0
gate() { # gate <NAME> <expected-desc> <0-pass|1-fail> [detail]
  if [ "$3" -eq 0 ]; then printf 'PASS  %-24s %s\n' "$1" "$2";
  else printf 'FAIL  %-24s %s %s\n' "$1" "$2" "${4:-}"; FAIL=$((FAIL+1)); fi
}
info() { printf 'INFO  %s\n' "$1"; }

[ -f "$README" ] || { echo "FAIL  setup  README not found: $README"; exit 1; }

# ---------- (a) line count <= 60 ----------
LINES=$(wc -l < "$README" | tr -d ' ')
if [ "$LINES" -le 60 ]; then gate "A:lines<=60" "(lines=$LINES<=60)" 0
else gate "A:lines<=60" "(lines=$LINES>60)" 1 "lines=$LINES"; fi

# ---------- (b) lebay-word grep must be empty ----------
LEBAY='passionate|ninja|rockstar|expert|visionary|cutting-edge|robust|seamless|elevate|craft|delve|leverage|males|passion'
HITS=$(grep -i -E -n -o "$LEBAY" "$README" || true)
if [ -z "$HITS" ]; then gate "B:lebay-words" "(no lebay words)" 0
else gate "B:lebay-words" "(lebay words must be absent)" 1 "hits: $(echo "$HITS" | tr '\n' ' ')"; fi

# ---------- (c1) emoji <= 1 per line ----------
if command -v python3 >/dev/null 2>&1 && python3 -c 'pass' 2>/dev/null; then
  EMOJI_BAD=$(python3 - "$README" 2>/dev/null <<'PY'
import re,sys
p=sys.argv[1]
ranges=[(0x2190,0x21FF),(0x2600,0x27BF),(0x2B00,0x2BFF),(0x1F000,0x1FAFF),(0x1F300,0x1FAFF)]
def is_emoji(ch):
    o=ord(ch)
    return any(a<=o<=b for a,b in ranges) or o in (0x2B50,0x2764,0x2699,0xFE0F)
bad=[]
with open(p,encoding='utf-8') as f:
    for i,line in enumerate(f,1):
        clean=line.replace('️','').replace('\u200d','')  # strip VS16 + ZWJ joins: 1 grapheme ~= 1
        n=sum(1 for ch in clean if is_emoji(ch))
        if n>1: bad.append(f"{i}:{n}")
print(' '.join(bad))
PY
)
  if [ -z "$EMOJI_BAD" ]; then gate "C1:emoji<=1/line" "(max 1 emoji per line)" 0
  else gate "C1:emoji<=1/line" "(>1 emoji on line)" 1 "lines[$EMOJI_BAD]"; fi
else
  info "C1:emoji<=1/line SKIPPED (python3 missing)"
fi

# ---------- (c2) section emojis (### lines w/ non-ASCII) <= 2 ----------
SEC_EMOJI=$(grep -c -E '^###.*[^ -~]' "$README" || true)
if [ "$SEC_EMOJI" -le 2 ]; then gate "C2:section-emoji<=2" "(sections-with-emoji=$SEC_EMOJI<=2)" 0
else gate "C2:section-emoji<=2" "(sections-with-emoji=$SEC_EMOJI>2)" 1; fi

# ---------- (c3) shields (img.shields.io) <= 2 ----------
SHIELDS=$(grep -o -c 'img\.shields\.io' "$README" || true)
if [ "$SHIELDS" -le 2 ]; then gate "C3:shields<=2" "(shields=$SHIELDS<=2)" 0
else gate "C3:shields<=2" "(shields=$SHIELDS>2)" 1 "shields=$SHIELDS"; fi

# ---------- (d1) 'const andika' must be ABSENT ----------
if grep -q -E 'const[[:space:]]+andika' "$README"; then gate "D1:no-const-andika" "(const andika absent)" 1 "found 'const andika'"
else gate "D1:no-const-andika" "(const andika absent)" 0; fi

# ---------- (d2) code fences: <= 1 fenced block (<= 2 fence lines) ----------
FENCE_LINES=$(grep -c -E '^```' "$README" || true)
if [ "$FENCE_LINES" -le 2 ]; then gate "D2:fences<=1-block" "(fence-lines=$FENCE_LINES<=2)" 0
else gate "D2:fences<=1-block" "(fence-lines=$FENCE_LINES>2)" 1; fi

# ---------- (d3) kill-list widgets must be ABSENT ----------
KILL='skillicons\.dev|github-readme-stats|github-readme-streak|github-profile-trophy|readme-typing-svg|komarev|visitor-badge|profile-counter|contribution.*snake|snake.*\.svg|github-readme-activity-graph|icon-wall'
KILLHITS=$(grep -i -E -n -o "$KILL" "$README" || true)
if [ -z "$KILLHITS" ]; then gate "D3:kill-list-absent" "(no stats/trophy/snake/counter/typing/skillicons)" 0
else gate "D3:kill-list-absent" "(kill-list widgets forbidden)" 1 "hits: $(echo "$KILLHITS" | tr '\n' ' ')"; fi

# ---------- (d4) motto 'Still learning still making' count == 1 ----------
MOTTO=$(tr '[:upper:]' '[:lower:]' < "$README" | tr -cs 'a-z0-9 ' ' ' | grep -o -c 'still learning still making' || true)
if [ "$MOTTO" -eq 1 ]; then gate "D4:motto==1" "(motto count=1)" 0
else gate "D4:motto==1" "(motto count must ==1)" 1 "count=$MOTTO"; fi

# ---------- (d5) ASCII-art lines <= 60 chars ----------
ASCII_BAD=$(awk 'length($0)>60 && /(─|│|┌|┐|└|┘|├|┤|┬|┴|┼|╔|╗|╚|╝|═|║|━|┃)/{print NR": "length($0)}' "$README" || true)
if [ -z "$ASCII_BAD" ]; then gate "D5:ascii<=60ch" "(no ascii-art line >60ch)" 0
else gate "D5:ascii<=60ch" "(ascii-art line >60ch)" 1 "$ASCII_BAD"; fi

# ---------- (d6) markdown tables <= 3 cols ----------
TABLE_BAD=$(awk '/^\|/{n=gsub(/\|/,"|"); cols=n-1; if ($0 !~ /---/ && cols>3) print NR": "cols"cols"}' "$README" || true)
if [ -z "$TABLE_BAD" ]; then gate "D6:tables<=3cols" "(no table >3 cols)" 0
else gate "D6:tables<=3cols" "(table >3 cols)" 1 "$TABLE_BAD"; fi

# ---------- (d7) no HTML style= / bgcolor ----------
STYLEHITS=$(grep -i -n -E ' style=|bgcolor' "$README" || true)
if [ -z "$STYLEHITS" ]; then gate "D7:no-style-bgcolor" "(no style=/bgcolor)" 0
else gate "D7:no-style-bgcolor" "(style=/bgcolor forbidden)" 1 "$(echo "$STYLEHITS" | tr '\n' ' ')"; fi

# ---------- (e1) every http(s) link must curl to 200 ----------
URLS=$(grep -o -E 'https?://[^)"'"'"' <>]+' "$README" | sed 's/[.,;:!?)]*$//' | sort -u || true)
LINK_FAIL=""
if [ -z "$URLS" ]; then info "E1:links-200 no http links found"
else
  for u in $URLS; do
    code=$(curl -s -L -A 'Mozilla/5.0 (profile-verify)' --max-time 10 -o /dev/null -w '%{http_code}' "$u" 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then printf 'PASS  link %s -> %s\n' "$u" "$code"
    elif [ "$code" = "999" ] && case "$u" in *linkedin.com*) true;; *) false;; esac; then
      printf 'PASS  link %s -> %s (note: LinkedIn bot-block, human-alive, not dead)\n' "$u" "$code"
    else printf 'FAIL  link %s -> %s\n' "$u" "$code"; LINK_FAIL="$LINK_FAIL $u->$code"; fi
  done
  if [ -z "$LINK_FAIL" ]; then gate "E1:links-200" "(all http links 200)" 0
  else gate "E1:links-200" "(every http link must be 200)" 1 "$LINK_FAIL"; fi
fi

# ---------- (e2) malformed instagram absent ----------
IG_BAD=""
while IFS= read -r line; do
  case "$line" in *[Ii][Nn][Ss][Tt][Aa][Gg][Rr][Aa][Mm]*)
    case "$line" in *https://*instagram.com/*|*https://www.instagram.com/*) ;; *) IG_BAD="$IG_BAD $line";; esac;;
  esac
done < "$README"
if [ -z "$IG_BAD" ]; then gate "E2:instagram-ok" "(no malformed instagram)" 0
else gate "E2:instagram-ok" "(malformed instagram)" 1 "$IG_BAD"; fi

# ---------- (f) markdown render hint: fences + divs balanced ----------
FOPEN=$(grep -c '<div' "$README" || true); FCLOSE=$(grep -c '</div>' "$README" || true)
if [ $((FENCE_LINES % 2)) -eq 0 ] && [ "$FOPEN" -eq "$FCLOSE" ]; then
  gate "F:render-hint" "(fences balanced, div $FOPEN/$FCLOSE — render README preview to confirm)" 0
else
  gate "F:render-hint" "(unbalanced markup — render README preview)" 1 "fences=$FENCE_LINES div=$FOPEN/$FCLOSE"
fi

echo "----"
echo "RESULT: $FAIL gate(s) failing — $([ "$FAIL" -eq 0 ] && echo GREEN || echo RED)"
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
