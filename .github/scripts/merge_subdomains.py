#!/usr/bin/env python3
"""Merge shard results into data/subdomains/<domain>.json and data/subdomains-index.json.
Existing results are kept: a domain that returned nothing this time (tool/network hiccup) does NOT wipe
previous findings; new subdomains are added (append-only union), last_run is refreshed.
httpx results (data/subdomains/<domain>.json "http" list) are refreshed per host:port -- each probed
host's record is replaced with this run's result (status can change), hosts not probed this run keep
their last known result.
"""
import glob, json, os, re
from datetime import datetime, timezone

IPV4 = re.compile(r'^\d{1,3}(\.\d{1,3}){3}$')

INDEX = 'data/subdomains-index.json'
OUTDIR = 'data/subdomains'


def belongs_to(host, domain):
    """True if host is domain itself or a subdomain of it. Defense in depth: a probe result whose
    host isn't actually within the domain it was filed under is dropped rather than merged -- this
    has been observed once (see incident notes) with an unconfirmed root cause, so it stays as a
    permanent guard regardless of what upstream produced the mismatch."""
    host = (host or '').lower().rstrip('.')
    domain = (domain or '').lower().rstrip('.')
    return bool(host) and (host == domain or host.endswith('.' + domain))
os.makedirs(OUTDIR, exist_ok=True)
now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
roots = json.load(open('plan/roots.json')) if os.path.exists('plan/roots.json') else {}
index = json.load(open(INDEX)) if os.path.exists(INDEX) else {'domains': {}}
doms = index.setdefault('domains', {})


def http_records(domain):
    """Parse this run's httpx JSON-lines file for a domain into {url: record}."""
    recs = {}
    path = f'results/{domain}.http.jsonl'
    if not os.path.exists(path):
        # shards land in per-shard subdirectories when downloaded; fall back to a search
        matches = glob.glob(f'results/**/{domain}.http.jsonl', recursive=True)
        path = matches[0] if matches else None
    if not path or not os.path.exists(path):
        return recs
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        try:
            j = json.loads(line)
        except ValueError:
            continue
        host = j.get('input') or j.get('host') or ''
        if not belongs_to(host, domain):
            print(f'  dropped out-of-scope httpx result: {host!r} is not part of {domain!r}')
            continue
        url = j.get('url') or f"{j.get('scheme', 'http')}://{host}"
        recs[url] = {
            'url': url,
            'host': host,
            'port': j.get('port'),
            'status_code': j.get('status_code'),
            'title': j.get('title') or '',
            'webserver': j.get('webserver') or '',
            'technologies': j.get('technologies') or j.get('tech') or [],
            'cdn': bool(j.get('cdn') or j.get('cdn_name')),
            # httpx's exact JSON key for the resolved IP has varied across versions; accept a few
            # known candidates but only keep a value that actually looks like an IPv4 address.
            'ip': next((v for v in (j.get('ip'), j.get('a', [None])[0] if j.get('a') else None, j.get('host'))
                        if v and IPV4.match(str(v))), None),
            'checked': now,
        }
    return recs


done = 0
for f in glob.glob('results/**/*.txt', recursive=True):
    domain = os.path.basename(f)[:-4]
    found = {l.strip() for l in open(f) if l.strip()}
    path = f'{OUTDIR}/{domain}.json'
    old = json.load(open(path)) if os.path.exists(path) else {'subdomains': [], 'http': {}}
    merged = sorted(set(old.get('subdomains', [])) | found)

    old_http = {r['url']: r for r in old.get('http', [])} if isinstance(old.get('http'), list) else old.get('http', {})
    new_http = http_records(domain)
    merged_http = {**old_http, **new_http}  # this run's probe replaces stale data for hosts it re-checked

    doc = {
        'domain': domain, 'last_run': now, 'count': len(merged),
        'programs': sorted(roots.get(domain, old.get('programs', []))),
        'subdomains': merged,
        'http': sorted(merged_http.values(), key=lambda r: r['url']),
    }
    json.dump(doc, open(path, 'w'), indent=1); open(path, 'a').write('\n')
    doms[domain] = {'last_run': now, 'count': len(merged), 'live_count': len(merged_http),
                     'programs': doc['programs']}
    done += 1

# keep program mapping fresh for every known domain
for d, progs in roots.items():
    if d in doms:
        doms[d]['programs'] = sorted(progs)
index['generated_at'] = now
index['total_domains'] = len(doms)
index['total_subdomains'] = sum(v['count'] for v in doms.values())
index['total_live_hosts'] = sum(v.get('live_count', 0) for v in doms.values())
json.dump(index, open(INDEX, 'w'), indent=1, sort_keys=True); open(INDEX, 'a').write('\n')
print(f'merged {done} domains; index has {len(doms)} domains, {index["total_subdomains"]} subdomains, '
      f'{index["total_live_hosts"]} live hosts')
