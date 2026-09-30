#!/usr/bin/env python3
"""Sync data/subdomains/*.json (live hosts) into the Airtable "AI Hacker - VDP" base's
Targets table -- end-to-end, run automatically after each Subdomains workflow run.

Safe by design:
  - Never deletes a row. A target that drops out of the feed just stops being refreshed.
  - Never touches human-entered columns (Test status, Tester, Notes) on an existing row --
    only feed-derived columns get refreshed (Status code, Title, Web server, Technologies,
    IP, Port, CDN, Live since, Bounty, Severity, Instructions).
  - New live URLs are created with Test status = "Untested".
  - Skips entirely (exit 0) if AIRTABLE_TOKEN isn't set, so this never fails a workflow run
    for a clone/fork that hasn't configured the secret.
"""
import glob, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request

BASE = 'apphZDAC7tZoQoxhw'
PROGRAMS_TABLE = 'tblGntuIOgfFFQlsm'
TARGETS_TABLE = 'tblUYLUjWrWHo2bv7'
REPO_ROOT = os.environ.get('GITHUB_WORKSPACE') or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TOKEN = os.environ.get('AIRTABLE_TOKEN')
if not TOKEN:
    print('AIRTABLE_TOKEN not set; skipping Airtable sync.')
    sys.exit(0)

FEED_FIELDS = ['Status code', 'Title', 'Web server', 'Technologies', 'IP', 'Port', 'CDN', 'Live since',
               'Bounty', 'Severity', 'Instructions']


def api(method, path, body=None):
    req = urllib.request.Request(
        'https://api.airtable.com' + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': 'Bearer ' + TOKEN, 'Content-Type': 'application/json'})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(2 * (attempt + 1))
                continue
            raise RuntimeError(f'{e.code} {e.read().decode()[:500]}')
    raise RuntimeError('rate limited repeatedly')


def list_all(table, fields):
    out, offset = [], None
    q = '&'.join(f'fields%5B%5D={urllib.parse.quote(f)}' for f in fields)
    while True:
        r = api('GET', f'/v0/{BASE}/{table}?pageSize=100&{q}' + (f'&offset={offset}' if offset else ''))
        out += r['records']
        offset = r.get('offset')
        if not offset:
            break
    return out


def main():
    programs = list_all(PROGRAMS_TABLE, ['Key'])
    prog_by_key = {r['fields'].get('Key'): r['id'] for r in programs}
    print(f'{len(prog_by_key)} programs in Airtable')

    enr = json.load(open(f'{REPO_ROOT}/data/programs-enriched.json'))
    meta_by_root = {}
    for p in enr['programs']:
        key = f"{p.get('platform')}|{p.get('handle')}"
        for t in p.get('targets') or []:
            tg = str(t.get('target') or '')
            ty = str(t.get('type') or '').upper()
            if ty != 'WILDCARD' and not tg.startswith('*.'):
                continue
            root = re.sub(r'^\*\.', '', tg).lower()
            meta_by_root[(key, root)] = {
                'Bounty': 'Yes' if t.get('bounty') else 'No',
                'Severity': t.get('severity') or '',
                'Instructions': (t.get('instruction') or '')[:2000],
            }

    existing = list_all(TARGETS_TABLE, ['Key', 'Target', 'Test status', 'Tester', 'Notes'] + FEED_FIELDS)
    existing_by_key_target = {(r['fields'].get('Key'), r['fields'].get('Target')): r for r in existing}
    print(f'{len(existing)} existing target rows in Airtable')

    to_create, to_update, to_delete = [], [], []
    seen = set()
    for path in glob.glob(f'{REPO_ROOT}/data/subdomains/*.json'):
        doc = json.load(open(path))
        domain = doc['domain']
        http = doc.get('http') or []
        if not http:
            continue
        prog_keys = doc.get('programs') or []
        key = next((k for k in prog_keys if k in prog_by_key), None)
        if not key:
            continue
        meta = meta_by_root.get((key, domain), {'Bounty': '', 'Severity': '', 'Instructions': ''})

        # When a host has both port 80 and port 443 live, they're the same web service (plain
        # vs TLS) -- represent them as one Target row (keyed by the 443/https URL) instead of
        # two. Any other port on the same host (8080, 8443, ...) stays its own row untouched.
        by_host = {}
        for h in http:
            host = h['url'].split('://', 1)[-1].split(':')[0].split('/')[0]
            by_host.setdefault(host, {})[str(h.get('port') or '')] = h
        merged_http = []
        redundant_port80_urls = []
        for host, ports in by_host.items():
            if '80' in ports and '443' in ports:
                primary, secondary = ports['443'], ports['80']
                combined = dict(primary)
                combined['port'] = '80, 443'
                combined['technologies'] = sorted(set((primary.get('technologies') or [])
                                                        + (secondary.get('technologies') or [])))
                merged_http.append(combined)
                redundant_port80_urls.append(secondary['url'][:1000])
                ports = {p: v for p, v in ports.items() if p not in ('80', '443')}
            merged_http.extend(ports.values())

        for old_url in redundant_port80_urls:
            old_rec = existing_by_key_target.get((key, old_url))
            if old_rec is None:
                continue
            f = old_rec['fields']
            human_touched = f.get('Test status', 'Untested') != 'Untested' or f.get('Tester') or f.get('Notes')
            if human_touched:
                print(f'  SKIP delete (has human data, review manually): {old_url}')
                continue
            to_delete.append(old_rec['id'])

        for h in merged_http:
            url = h['url'][:1000]
            seen.add((key, url))
            new_fields = {
                'Status code': h.get('status_code'),
                'Title': (h.get('title') or '')[:500],
                'Web server': h.get('webserver') or '',
                'Technologies': ', '.join(h.get('technologies') or []),
                'IP': h.get('ip') or '',
                'Port': str(h.get('port') or ''),
                'CDN': bool(h.get('cdn')),
                'Live since': (h.get('checked') or '')[:19],
                **meta,
            }
            existing_rec = existing_by_key_target.get((key, url))
            if existing_rec is None:
                to_create.append({'fields': {
                    'Target': url, 'Program': [prog_by_key[key]], 'Type': 'URL', 'Scope': 'In scope',
                    'Feed updated': domain, 'Test status': 'Untested', 'Key': key, **new_fields,
                }})
            else:
                cur = existing_rec['fields']
                # Airtable omits a field entirely from the response when it's "empty" -- None for
                # text, and also False for a checkbox (an unchecked box is never sent as `false`,
                # just absent). Treat those as equal to their own empty value so an unchanged
                # record never gets flagged as "changed" just because Airtable's GET omits it.
                EMPTY = (None, '', False)
                changed = {k: v for k, v in new_fields.items()
                           if cur.get(k) != v and not (cur.get(k) in EMPTY and v in EMPTY)}
                if changed:
                    to_update.append({'id': existing_rec['id'], 'fields': changed})

    to_delete = sorted(set(to_delete))
    print(f'to create: {len(to_create)}, to update: {len(to_update)}, '
          f'to delete (redundant port-80 rows merged into 80+443): {len(to_delete)}, '
          f'unchanged: {len(seen) - len(to_create) - len(to_update)}')

    for i in range(0, len(to_create), 10):
        api('POST', f'/v0/{BASE}/{TARGETS_TABLE}', {'records': to_create[i:i + 10], 'typecast': True})
        time.sleep(0.22)
    for i in range(0, len(to_update), 10):
        api('PATCH', f'/v0/{BASE}/{TARGETS_TABLE}', {'records': to_update[i:i + 10], 'typecast': True})
        time.sleep(0.22)
    for i in range(0, len(to_delete), 10):
        chunk = to_delete[i:i + 10]
        api('DELETE', f'/v0/{BASE}/{TARGETS_TABLE}?' + '&'.join(f'records%5B%5D={x}' for x in chunk))
        time.sleep(0.22)

    print(f'done: created {len(to_create)}, updated {len(to_update)}, deleted {len(to_delete)}')


if __name__ == '__main__':
    main()
