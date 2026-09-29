#!/usr/bin/env python3
"""Merge shard results into data/subdomains/<domain>.json and data/subdomains-index.json.
Existing results are kept: a domain that returned nothing this time (tool/network hiccup) does NOT wipe
previous findings; new subdomains are added (append-only union), last_run is refreshed.
"""
import glob, json, os
from datetime import datetime, timezone

INDEX = 'data/subdomains-index.json'
OUTDIR = 'data/subdomains'
os.makedirs(OUTDIR, exist_ok=True)
now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
roots = json.load(open('plan/roots.json')) if os.path.exists('plan/roots.json') else {}
index = json.load(open(INDEX)) if os.path.exists(INDEX) else {'domains': {}}
doms = index.setdefault('domains', {})

done = 0
for f in glob.glob('results/**/*.txt', recursive=True):
    domain = os.path.basename(f)[:-4]
    found = {l.strip() for l in open(f) if l.strip()}
    path = f'{OUTDIR}/{domain}.json'
    old = json.load(open(path)) if os.path.exists(path) else {'subdomains': []}
    merged = sorted(set(old.get('subdomains', [])) | found)
    doc = {'domain': domain, 'last_run': now, 'count': len(merged), 'programs': sorted(roots.get(domain, old.get('programs', []))),
           'subdomains': merged}
    json.dump(doc, open(path, 'w'), indent=1); open(path, 'a').write('\n')
    doms[domain] = {'last_run': now, 'count': len(merged), 'programs': doc['programs']}
    done += 1

# keep program mapping fresh for every known domain
for d, progs in roots.items():
    if d in doms:
        doms[d]['programs'] = sorted(progs)
index['generated_at'] = now
index['total_domains'] = len(doms)
index['total_subdomains'] = sum(v['count'] for v in doms.values())
json.dump(index, open(INDEX, 'w'), indent=1, sort_keys=True); open(INDEX, 'a').write('\n')
print(f'merged {done} domains; index has {len(doms)} domains, {index["total_subdomains"]} subdomains')
