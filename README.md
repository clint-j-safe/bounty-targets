# bounty-targets-data [![Last commit](https://img.shields.io/github/last-commit/clint-j-safe/bounty-targets.svg)](https://github.com/clint-j-safe/bounty-targets/commits/main) [![License](https://img.shields.io/github/license/clint-j-safe/bounty-targets.svg)](https://github.com/clint-j-safe/bounty-targets/blob/main/LICENSE.md)

### What's it for

This repo contains data dumps of Hackerone and Bugcrowd scopes (i.e. the domains that are eligible for bug bounty reports). The files provided are:

Main files:
- [domains.txt](https://github.com/clint-j-safe/bounty-targets/blob/main/data/domains.txt): full list of domains, without wildcards.
- [wildcards.txt](https://github.com/clint-j-safe/bounty-targets/blob/main/data/wildcards.txt): full list of wildcard domains. **Note:** A program might have `*.example.com` in-scope but `excluded.example.com` out-of-scope so check your program rules before submitting reports.
- [programs.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/programs.json): normalized list of every program across all platforms, including metadata to prioritize targets (first enrollment date, last update date, bounty ranges, report counts) and its in-scope / out-of-scope targets.

Extra files:
- [bugcrowd_data.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/bugcrowd_data.json): raw [Bugcrowd](https://bugcrowd.com) data.
- [hackerone_data.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/hackerone_data.json): raw [Hackerone](https://hackerone.com) data.
- [federacy_data.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/federacy_data.json): raw [Federacy](https://federacy.com) data.
<!-- - [hackenproof_data.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/hackenproof_data.json): raw [Hackenproof](https://hackenproof.com) data. -->
- [intigriti_data.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/intigriti_data.json): raw [Intigriti](https://www.intigriti.com) data.
- [yeswehack_data.json](https://github.com/clint-j-safe/bounty-targets/blob/main/data/yeswehack_data.json): raw [YesWeHack](https://www.yeswehack.com/) data.

### programs.json

`programs.json` is the normalized version of the raw dumps above: one entry per program across all platforms, with the metadata needed to prioritize targets.

- Top level: `generated_at` (ISO 8601 timestamp) and `programs` (array sorted by `last_updated_at` descending, programs with an unknown date come last).
- Each program: `platform`, `id`, `handle`, `name`, `url`, `offers_bounty`, `submission_state`, `managed`, `first_started_at`, `last_updated_at`, `last_activity_at`, `reports_count`, `resolved_reports_count`, `total_bounty_amount`, `bounty_min`, `bounty_max`, `targets`.
- Each target: `type`, `target`, `in_scope`, `bounty`, `updated_at`, `severity`, `instruction`.

Timestamps are UTC ISO 8601 strings. Flags are `true` / `false` / `null`, where `null` means the platform does not expose that value (for example `bounty` is `null` when neither the program nor the target declares a bounty). Out-of-scope targets are included with `in_scope: false`.

`id` and `handle` identify the program on its source platform; when only one of them is exposed the other is derived from it (HackerOne ids fall back to the program handle, Bugcrowd and Federacy handles are taken from the program URL).

### Status

The last change was detected on `Monday 09/28/2026 19:46 (UTC)`. New changes (if any) are picked up every 6 hours.

### Code

The code used to generate these files lives in the [bounty-targets](https://github.com/clint-j-safe/bounty-targets) repo (a fork of arkadiyt/bounty-targets).

### Getting in touch

Feel free to contact me on Signal: @arkadiyt.01
