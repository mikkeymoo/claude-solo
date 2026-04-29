---
name: mm:nuix-binary-store
description: Prudential Nuix binary store workflow — Phase 1 scan, Phase 2 MD5 extraction (handles v9.2 vs v9.10 routing), Phase 3 orphan detection. Use when: nuix, binary store, prudential, orphan, md5 extraction.
---

# /nuix-binary-store — Nuix Binary Store Workflow

Three-phase Prudential binary store audit. Handles Nuix 9.2 and 9.10 API differences.

## Phase 1: Scan cases for binary store paths

Produce a Ruby script that:

1. Connects to the Nuix case list
2. Iterates each case and reads `getBinaryStores()` or `getCaseProperties().getBinaryStorePath()` depending on version
3. Outputs CSV: `case_guid, case_name, binary_store_path, nuix_version`

```ruby
# Template: scan-binary-stores.rb
require 'json'

# Insert Nuix utilities path
$utilities = $utilities  # provided by Nuix scripting context

cases = $utilities.getCaseFactory.listCases(java.io.File.new(CASES_DIR))
results = []

cases.each do |case_ref|
  begin
    nuix_case = $utilities.getCaseFactory.open(case_ref.getLocation)
    version = nuix_case.getMetrics().getNuixVersion() rescue "unknown"

    # v9.2 vs v9.10 routing
    if version.start_with?("9.1")
      store_path = nuix_case.getBinaryStores().first&.getLocation&.getPath rescue nil
    else
      store_path = nuix_case.getMetrics().getCaseProperties()["binaryStorePath"] rescue nil
    end

    results << {
      guid: nuix_case.getGuid(),
      name: nuix_case.getName(),
      store_path: store_path,
      version: version
    }
    nuix_case.close()
  rescue => e
    STDERR.puts "Error on #{case_ref}: #{e.message}"
  end
end

puts results.map { |r| [r[:guid], r[:name], r[:store_path], r[:version]].join(",") }.join("\n")
```

## Phase 2: Extract MD5 hashes

Given the binary store paths from Phase 1:

1. For each binary store directory, recursively find all `.db` files (Nuix stores MD5s in SQLite)
2. Query: `SELECT hash, file_path FROM binary_store_entries` (schema varies: 9.2 uses `entries`, 9.10 uses `items`)
3. Output flat CSV: `md5, binary_store_path, relative_file_path`

Handle version routing:

- Nuix 9.2: table `entries`, column `hash`
- Nuix 9.10+: table `items`, column `md5_hash`

## Phase 3: Orphan detection

Compare MD5 hashes from binary stores against active case items:

1. Load case item hashes via Nuix search: `flag:audited`
2. Cross-reference with Phase 2 output
3. Report orphaned binary store entries (in store, not in any active case)

Output: `orphan_report.csv` with columns: `md5, binary_store_path, last_seen_case, size_bytes`

## Usage

```
/nuix-binary-store phase1 --cases-dir "D:\NuixCases" --output phase1.csv
/nuix-binary-store phase2 --phase1-csv phase1.csv --output md5s.csv
/nuix-binary-store phase3 --md5s-csv md5s.csv --active-cases "case1,case2" --output orphans.csv
```

## Prerequisites

- Nuix Workstation or Server with scripting license
- Ruby runtime (bundled with Nuix)
- Write access to output directory
- Binary store paths readable from script host
