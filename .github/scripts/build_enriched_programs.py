#!/usr/bin/env python3
"""Build data/programs-enriched.json: data/programs.json with subdomain-enumeration and httpx
results attached to each in-scope wildcard target, wherever data/subdomains/<root>.json exists.

Every program and target from programs.json is kept as-is; only wildcard targets that have been
enumerated (see .github/workflows/subdomains.yml) gain an "enrichment" object. A wildcard target
with no matching data/subdomains/<root>.json file (not enumerated yet) is left unchanged -- no
"enrichment" key -- so this stays correct to run at any point, complete data or not.
"""
import glob, json, os, re
from datetime import datetime, timezone

PROGRAMS = 'data/programs.json'
SUBDOMAINS_DIR = 'data/subdomains'
OUT = 'data/programs-enriched.json'


def root_of(target_type, target):
    """Wildcard root domain for a target, or None if this target isn't a wildcard."""
    t = str(target or '').strip().lower()
    if str(target_type).upper() != 'WILDCARD' and not t.startswith('*.'):
        return None
    return re.sub(r'^\*\.', '', t) or None


def load_enrichment_index():
    """root domain -> parsed data/subdomains/<root>.json (only files that parse cleanly)."""
    index = {}
    for path in glob.glob(f'{SUBDOMAINS_DIR}/*.json'):
        try:
            doc = json.load(open(path))
        except ValueError:
            continue
        domain = doc.get('domain') or os.path.basename(path)[:-5]
        index[domain] = doc
    return index


def main():
    data = json.load(open(PROGRAMS))
    enrichment = load_enrichment_index()
    enriched_targets = 0

    for program in data.get('programs', []):
        for target in program.get('targets') or []:
            if target.get('in_scope') is not True:
                continue
            root = root_of(target.get('type'), target.get('target'))
            if not root:
                continue
            doc = enrichment.get(root)
            if not doc:
                continue
            target['enrichment'] = {
                'root_domain': root,
                'last_enumerated': doc.get('last_run'),
                'subdomain_count': doc.get('count', len(doc.get('subdomains', []))),
                'subdomains': doc.get('subdomains', []),
                'live_host_count': len(doc.get('http', [])),
                'live_hosts': doc.get('http', []),
            }
            enriched_targets += 1

    data['enrichment_generated_at'] = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    data['enrichment_domains_available'] = len(enrichment)
    data['enrichment_targets_enriched'] = enriched_targets

    json.dump(data, open(OUT, 'w'), indent=2)
    open(OUT, 'a').write('\n')
    print(f'{OUT}: {enriched_targets} targets enriched from {len(enrichment)} enumerated domains')


if __name__ == '__main__':
    main()
