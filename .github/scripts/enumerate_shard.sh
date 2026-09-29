#!/usr/bin/env bash
# Usage: enumerate_shard.sh <shard-file> <subdomz-dir> <out-dir>
# Runs SubDomz passively (no probing, no brute force, no direct target contact) one domain at a time.
set -u
SHARD="$1"; SZ="$2"; OUT="$3"
PER_DOMAIN_TIMEOUT="${PER_DOMAIN_TIMEOUT:-420}"   # seconds
PAUSE="${PAUSE_BETWEEN_DOMAINS:-8}"               # seconds: rate limit between domains
mkdir -p "$OUT"

# Passive, key-less sources only (no API keys needed). Cero (contacts targets) is excluded. SubDomz's own Puredns function is broken (uses an unset $DOMAIN), so puredns is run directly below.
SOURCES="Subfinder,Assetfinder,Findomain,Crtsh,JLDC,Alienvault,Subdomain-center,Certspotter"
# SecurityTrails (via SubDomz's Haktrails source) is implemented but OFF by default.
# It only runs when ENABLE_SECURITYTRAILS=true AND a haktrails config with a key exists.
if [ "${ENABLE_SECURITYTRAILS:-false}" = "true" ] && [ -s "$HOME/.config/haktools/haktrails-config.yml" ] && command -v haktrails >/dev/null; then
  SOURCES="$SOURCES,Haktrails"
  echo "SecurityTrails enabled"
fi

cd "$SZ"
while IFS= read -r domain; do
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
  sleep "$PAUSE"
done < "$SHARD"
