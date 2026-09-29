#!/usr/bin/env python3
"""Decide which in-scope wildcard root domains to enumerate this run.

Order: never-run (new) domains first, then domains last run >= REFRESH_DAYS ago (oldest first).
Capped by MAX_DOMAINS (rate limit) and split into shards of SHARD_SIZE for a matrix of batches.
Outputs (GITHUB_OUTPUT): matrix (JSON list of shard ids), count. Writes shard files to plan/.
"""
import json, os, re, sys
from datetime import datetime, timedelta, timezone

DATA = 'data/programs.json'
INDEX = 'data/subdomains-index.json'
MAX_DOMAINS = int(os.environ.get('MAX_DOMAINS') or 240)
SHARD_SIZE = int(os.environ.get('SHARD_SIZE') or 30)
REFRESH_DAYS = int(os.environ.get('REFRESH_DAYS') or 30)

# strict: letters/digits/hyphen labels, at least one dot, alphabetic TLD. Anything else is dropped,
# because these strings come from third-party program pages and are passed to shell tools.
DOMAIN = re.compile(r'^(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$')


def wildcard_roots(programs):
    roots = {}
    for p in programs:
        key = f"{p.get('platform')}|{p.get('handle')}"
        for t in p.get('targets') or []:
            tg = str(t.get('target') or '').strip().lower()
            if t.get('in_scope') is not True:
                continue
            if not (str(t.get('type')).upper() == 'WILDCARD' or tg.startswith('*.')):
                continue
            root = re.sub(r'^\*\.', '', tg)
            if DOMAIN.match(root):
                roots.setdefault(root, set()).add(key)
    return roots


def main():
    programs = json.load(open(DATA))['programs']
    roots = wildcard_roots(programs)
    index = json.load(open(INDEX)) if os.path.exists(INDEX) else {'domains': {}}
    known = index.get('domains', {})
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=REFRESH_DAYS)

    new = sorted(d for d in roots if d not in known)
    due = sorted((d for d in roots if d in known and datetime.fromisoformat(known[d]['last_run']) <= cutoff),
                 key=lambda d: known[d]['last_run'])
    todo = (new + due)[:MAX_DOMAINS]
    print(f'roots={len(roots)} new={len(new)} due={len(due)} this_run={len(todo)} (cap {MAX_DOMAINS})')

    os.makedirs('plan', exist_ok=True)
    shards = [todo[i:i + SHARD_SIZE] for i in range(0, len(todo), SHARD_SIZE)]
    for n, s in enumerate(shards):
        open(f'plan/shard-{n}.txt', 'w').write('\n'.join(s) + '\n')
    json.dump({d: sorted(v) for d, v in roots.items()}, open('plan/roots.json', 'w'))
    out = os.environ.get('GITHUB_OUTPUT')
    if out:
        with open(out, 'a') as f:
            f.write(f'matrix={json.dumps(list(range(len(shards))))}\n')
            f.write(f'count={len(todo)}\n')


if __name__ == '__main__':
    sys.exit(main())
