#!/usr/bin/env python3
"""Create Airtable Findings records from a JSON file -- the "upload JSON" path Airtable's own
Forms/Omni can't do (Forms are manual field-by-field entry only; confirmed directly with Omni).

Usage:
    AIRTABLE_TOKEN=... python3 submit_findings.py path/to/finding.json
    AIRTABLE_TOKEN=... python3 submit_findings.py path/to/findings-array.json

Input is one finding object, or a JSON array of them. Every created record is forced to
Status = "New" regardless of what's in the JSON -- nothing skips triage review just because
it came in as a file instead of the form. Program/Reporter/Target are resolved by lookup
(program Key or name; reporter Name in the Users table; target by exact URL in Targets), so a
typo there fails loudly per-record rather than silently linking the wrong thing.

Expected JSON keys (all optional except title and program):
  title, program (Key like "hackerone|equifax", or the Program name), target_url (matched
  against an existing Targets row), affected_url, vulnerability_type, severity, cvss_score,
  cwe, asset_type, description, steps_to_reproduce, impact, proof_of_concept,
  request_response, reporter (a Name from the Users table), date_found (YYYY-MM-DD), tags,
  attachments (list of public URLs -- Airtable fetches these server-side; local file uploads
  aren't supported through this path).
"""
import json, os, sys, urllib.error, urllib.request

BASE = 'apphZDAC7tZoQoxhw'
FINDINGS_TABLE = 'tblJQuufA52FDqDdz'
PROGRAMS_TABLE = 'tblGntuIOgfFFQlsm'
TARGETS_TABLE = 'tblUYLUjWrWHo2bv7'
USERS_TABLE = 'tblxJcMsq0wiYGuIS'

TOKEN = os.environ.get('AIRTABLE_TOKEN')
if not TOKEN:
    sys.exit('AIRTABLE_TOKEN is not set.')

FIELD_MAP = {
    'title': 'Title', 'affected_url': 'Affected URL', 'vulnerability_type': 'Vulnerability type',
    'severity': 'Severity', 'cvss_score': 'CVSS score', 'cwe': 'CWE', 'asset_type': 'Asset type',
    'description': 'Description', 'steps_to_reproduce': 'Steps to reproduce', 'impact': 'Impact',
    'proof_of_concept': 'Proof of concept', 'request_response': 'Request / response',
    'date_found': 'Date found', 'tags': 'Tags',
}


def api(method, path, body=None):
    req = urllib.request.Request(
        'https://api.airtable.com' + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': 'Bearer ' + TOKEN, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{e.code} {e.read().decode()[:500]}')


def list_all(table, fields):
    out, offset = [], None
    q = '&'.join(f'fields%5B%5D={f}' for f in fields)
    while True:
        r = api('GET', f'/v0/{BASE}/{table}?pageSize=100&{q}' + (f'&offset={offset}' if offset else ''))
        out += r['records']
        offset = r.get('offset')
        if not offset:
            break
    return out


def build_record(finding, prog_by_key_or_name, users_by_name, target_by_url):
    fields = {}
    for k, airtable_name in FIELD_MAP.items():
        if finding.get(k) not in (None, ''):
            fields[airtable_name] = finding[k]

    prog = finding.get('program')
    if prog:
        rec_id = prog_by_key_or_name.get(prog)
        if not rec_id:
            raise ValueError(f'Unknown program: {prog!r}')
        fields['Program'] = [rec_id]

    target_url = finding.get('target_url')
    if target_url:
        rec_id = target_by_url.get(target_url)
        if rec_id:
            fields['Target'] = [rec_id]
        elif 'Affected URL' not in fields:
            fields['Affected URL'] = target_url  # fall back to free text if not an enumerated Target

    reporter = finding.get('reporter')
    if reporter:
        rec_id = users_by_name.get(reporter)
        if not rec_id:
            raise ValueError(f'Unknown reporter: {reporter!r} (not in the Users table)')
        fields['Reporter'] = [rec_id]

    attachments = finding.get('attachments')
    if attachments:
        fields['Attachments'] = [{'url': u} for u in attachments]

    fields['Status'] = 'New'  # always -- JSON intake never bypasses triage
    return {'fields': fields}


def main():
    if len(sys.argv) != 2:
        sys.exit('Usage: submit_findings.py <finding.json | findings-array.json>')
    data = json.load(open(sys.argv[1]))
    findings = data if isinstance(data, list) else [data]

    programs = list_all(PROGRAMS_TABLE, ['Key', 'Program'])
    prog_lookup = {}
    for r in programs:
        f = r['fields']
        if f.get('Key'):
            prog_lookup[f['Key']] = r['id']
        if f.get('Program'):
            prog_lookup[f['Program']] = r['id']

    users = list_all(USERS_TABLE, ['Name'])
    users_by_name = {r['fields'].get('Name'): r['id'] for r in users if r['fields'].get('Name')}

    targets = list_all(TARGETS_TABLE, ['Target'])
    target_by_url = {r['fields'].get('Target'): r['id'] for r in targets if r['fields'].get('Target')}

    records, errors = [], []
    for i, finding in enumerate(findings):
        try:
            records.append(build_record(finding, prog_lookup, users_by_name, target_by_url))
        except ValueError as e:
            errors.append(f'finding[{i}] ({finding.get("title", "?")}): {e}')

    if errors:
        print('Skipped (fix and re-run these):')
        for e in errors:
            print(' ', e)

    created = 0
    for i in range(0, len(records), 10):
        r = api('POST', f'/v0/{BASE}/{FINDINGS_TABLE}', {'records': records[i:i + 10], 'typecast': True})
        created += len(r['records'])
    print(f'Created {created} finding(s), all Status = New.')


if __name__ == '__main__':
    main()
