#!/usr/bin/env bash
# Usage: enumerate_shard.sh <shard-file> <subdomz-dir> <out-dir>
# Runs SubDomz passively (no probing, no brute force, no direct target contact) one domain at a time.
set -u
SHARD="$1"; SZ="$2"; OUT="$3"
PER_DOMAIN_TIMEOUT="${PER_DOMAIN_TIMEOUT:-420}"   # seconds
PAUSE="${PAUSE_BETWEEN_DOMAINS:-5}"               # seconds: rate limit between domains
mkdir -p "$OUT"
# Resolve caller-relative paths to absolute now: the script cd's into $SZ below, after which any
# relative $SHARD/$OUT path would silently resolve against $SZ instead of the caller's cwd.
SHARD="$(cd "$(dirname "$SHARD")" && pwd)/$(basename "$SHARD")"
OUT="$(cd "$OUT" && pwd)"

# Passive, key-less sources only (no API keys needed). Cero (contacts targets) is excluded. SubDomz's own Puredns function is broken (uses an unset $DOMAIN), so puredns is run directly below.
# SubDomz's own -p/--parallel flag does nothing here: per its source, that path only applies when
# no -u/-e is given, and we always pass -u. Real bottleneck (measured) is httpx below, not SubDomz.
# Common web / alt-http(s) ports probed with httpx. Trimmed from an earlier ~78-port list: benchmarked
# locally (real httpx, real network, same 20-host input) at threads=50/timeout=8/retries=1/78 ports =
# 6m3.7s for 81 live results, vs threads=100/timeout=5/retries=0/this list = 38.2s for 33 live results.
# ~9.5x faster while still covering the ports that matter; a request timeout on a closed/filtered port
# was the dominant cost, not the target's real response time.
WEB_PORTS="80,81,300,443,591,3000,8000,8001,8008,8080,8081,8090,8443,8888,9000,9090,9443,2082,2083,2087,2095,2096"
SOURCES="Subfinder,Assetfinder,Findomain,Crtsh,JLDC,Alienvault,Subdomain-center,Certspotter"
# SecurityTrails (via SubDomz's Haktrails source) is implemented but OFF by default.
# It only runs when ENABLE_SECURITYTRAILS=true AND a haktrails config with a key exists.
if [ "${ENABLE_SECURITYTRAILS:-false}" = "true" ] && [ -s "$HOME/.config/haktools/haktrails-config.yml" ] && command -v haktrails >/dev/null; then
  SOURCES="$SOURCES,Haktrails"
  echo "SecurityTrails enabled"
fi

cd "$SZ"
# Read the shard list on fd 3, NOT stdin: SubDomz/puredns/httpx run inside this loop, and at
# least httpx (confirmed by local repro) auto-reads stdin as EXTRA targets when it's not a TTY.
# If the loop's own domain queue were on stdin, a child process reading stdin would silently
# consume later domains from the SAME shard file as bogus additional httpx targets -- this was
# a real, reproduced bug (see incident notes), not a hypothetical.
while IFS= read -r domain <&3; do
  [ -z "$domain" ] && continue
  # defence in depth: planner already validated, re-check before it reaches an unquoted shell variable
  if ! printf '%s' "$domain" | grep -Eq '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$'; then
    echo "skip invalid: $domain"; continue
  fi
  rm -f subdomz-"$domain".txt tmp-*
  timeout "$PER_DOMAIN_TIMEOUT" bash ./SubDomz.sh -d "$domain" -u "$SOURCES" -s >/dev/null 2>&1
  rc=$?
  if [ -f "subdomz-$domain.txt" ]; then
    # keep only the domain itself and its subdomains, lowercase, unique
    tr 'A-Z' 'a-z' < "subdomz-$domain.txt" | sed 's/^\*\.//' \
      | grep -E "(^|\.)$(printf '%s' "$domain" | sed 's/\./\\./g')\$" | sort -u > "$OUT/$domain.txt"
  else
    : > "$OUT/$domain.txt"
  fi
  # DNS brute force with puredns (on by default; set DISABLE_PUREDNS=true to skip).
  # Wildcard DNS responses are filtered by puredns; queries go through public resolvers, rate limited.
  if [ "${DISABLE_PUREDNS:-false}" != "true" ] && command -v puredns >/dev/null \
     && [ -s "${DNS_DIR:-}/words.txt" ] && [ -s "${DNS_DIR:-}/resolvers.txt" ]; then
    timeout "${PUREDNS_TIMEOUT:-300}" puredns bruteforce "$DNS_DIR/words.txt" "$domain" \
      -r "$DNS_DIR/resolvers.txt" --rate-limit "${PUREDNS_RATE:-1000}" --rate-limit-trusted "${PUREDNS_RATE_TRUSTED:-100}" \
      -q 2>/dev/null | tr 'A-Z' 'a-z' | grep -E "(^|\.)$(printf '%s' "$domain" | sed 's/\./\\./g')\$" >> "$OUT/$domain.txt"
    sort -u -o "$OUT/$domain.txt" "$OUT/$domain.txt"
  fi
  echo "$domain rc=$rc found=$(wc -l < "$OUT/$domain.txt")"

  # HTTP probe on common web ports with httpx (on by default; set DISABLE_HTTPX=true to skip).
  # Probes only the hosts just collected for this domain (root + subdomains found above).
  if [ "${DISABLE_HTTPX:-false}" != "true" ] && command -v httpx >/dev/null && [ -s "$OUT/$domain.txt" ]; then
    timeout "${HTTPX_TIMEOUT:-150}" httpx -l "$OUT/$domain.txt" -ports "$WEB_PORTS" \
      -json -silent -status-code -title -web-server -tech-detect -ip -cdn \
      -timeout "${HTTPX_REQ_TIMEOUT:-5}" -retries "${HTTPX_RETRIES:-0}" -threads "${HTTPX_THREADS:-100}" -rate-limit "${HTTPX_RATE:-150}" \
      -o "$OUT/$domain.http.jsonl" < /dev/null 2>/dev/null  # belt-and-suspenders: see fd 3 note above
    echo "$domain httpx_live=$(wc -l < "$OUT/$domain.http.jsonl" 2>/dev/null || echo 0)"
  fi
  sleep "$PAUSE"
done 3< "$SHARD"
