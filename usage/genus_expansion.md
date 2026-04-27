# nf-core/mhcrefseq: Expanding genus inputs into a species panel

> Standalone preprocessing notebook at `bin/expand_genera.ipynb`. Runs **before** `nextflow run`. The pipeline itself is unchanged.

## When to use this

The pipeline's default behavior for a single-token `scientific_name` (a bare genus) is to download **one arbitrary reference proteome** from that genus — see [input.md](./input.md). Most of the time that's the right tradeoff: small FASTA, species-level attribution preserved.

For a small number of samples where you'd rather have a **curated multi-species panel** for a genus, this notebook rewrites your samplesheet to replace each genus row with N species rows drawn from GTDB R226. The pipeline then runs on the expanded samplesheet exactly as if you had typed those species in by hand.

```
samplesheet.csv  ──►  bin/expand_genera.ipynb  ──►  samplesheet.expanded.csv  ──►  nextflow run ...
```

Best fit: 2–3 known genera in a one-off analysis. For larger or recurring needs, prefer typing the species you want directly in the samplesheet.

## Requirements

- Jupyter and Python ≥3.9 with `pandas`. No other dependencies — the notebook only uses the standard library besides pandas.
- Internet access: one-time GTDB download (~7 MB into `~/.cache/mhcrefseq/gtdb/`) and per-species UniProt REST calls.

## Configuration (Cell 1)

| Variable | Default | Notes |
| --- | --- | --- |
| `SAMPLESHEET_IN` | `samplesheet.csv` | path to your existing CSV |
| `SAMPLESHEET_OUT` | `samplesheet.expanded.csv` | what the pipeline will then consume |
| `AUDIT_LOG` | `expansion_audit.tsv` | per-sample record of what got picked |
| `GENERA_TO_EXPAND` | example list | **only** these genera get expanded; everything else passes through unchanged |
| `MAX_PER_GENUS` | `10` | cap on species drawn per genus |
| `RANDOM_SEED` | `42` | seed for the per-genus RNG; recorded in audit log |
| `COLLAPSE_GTDB_LINEAGES` | `True` | treat GTDB sub-clusters like *Escherichia coli_A* as one species |
| `UNIPROT_THROTTLE_SEC` | `0.1` | sleep between UniProt REST calls |

`GENERA_TO_EXPAND` is **explicit by design** — auto-detecting "single token = genus" silently expands typos. Listing the genera you want to expand documents your intent (and survives in your shell history / methods section).

## Cell-by-cell

The notebook is 10 code cells, each ending with `assert` checks that catch silent bugs at the boundary they happen at.

| # | Cell | What it does | What to look at |
| --- | --- | --- | --- |
| 1 | Imports & config | All the knobs | Check the values printed at the bottom |
| 2 | Download GTDB | Fetches `bac120_taxonomy_r226.tsv.gz` on first run; cache hit otherwise | SHA256 line — recorded in the audit log |
| 3 | Parse GTDB | Builds a ~700k-row DataFrame: `genome_id, genus, species_raw, species_collapsed, species` | Genome and species counts |
| 4 | Load samplesheet | Reads & validates input CSV | Row count and header; warning if any `GENERA_TO_EXPAND` value is missing from the samplesheet |
| 5 | Per-genus candidates | Lists every species in each target genus from GTDB | Eyeball the species list (truncated at 50 per genus for readability) |
| 6 | UniProt cross-check | One REST call per candidate; mirrors the pipeline's own `taxonomy_name:<sp>+AND+proteome_type:reference` query | `kept / dropped` summary per genus |
| 7 | Seeded random selection | Per-genus RNG seeded with `f"{RANDOM_SEED}:{genus}"`; samples up to `MAX_PER_GENUS` | The selected list per genus, plus an idempotency check |
| 8 | Build expanded samplesheet | Replaces genus rows with N species rows | Before/after row counts |
| 9 | Write outputs | CSV + audit TSV | Confirms output paths |
| 10 | Methods snippet | Ready-to-paste paragraph for your manuscript methods | Copy this when you publish |

## Outputs

```
samplesheet.expanded.csv   # feed this to `nextflow run --input ...`
expansion_audit.tsv        # per-genus: original input, GTDB/UniProt counts, picks, seed
~/.cache/mhcrefseq/gtdb/   # cached GTDB taxonomy, reused across runs
```

`expansion_audit.tsv` columns: `sample, original_input, gtdb_release, gtdb_sha256, n_in_gtdb, n_with_uniprot_proteome, n_selected, max_per_genus, random_seed, selected_species` (semicolon-joined).

## Reproducibility

Three things make a rerun bit-identical:

1. **GTDB release pinned** to R226 (`GTDB_RELEASE = "226.0"`). The SHA256 of the cached file is logged in the audit so an unexpected upstream change would show up as a mismatch on rerun.
2. **`RANDOM_SEED`** is a literal in the notebook. Same seed + same GTDB file + same `MAX_PER_GENUS` → same picks.
3. **Per-genus sub-RNG** (`f"{RANDOM_SEED}:{genus}"`) — adding or removing a genus from `GENERA_TO_EXPAND` does **not** perturb the picks for the other genera.

Why GTDB R226: it's the release packaged by nf-core/ampliseq as "R10-RS226", which is the typical source of the genus-level taxonomic identifications that produce these samplesheets in the first place. Using the same release keeps species concepts consistent across the upstream taxonomy step and this expansion step.

## Why random instead of "first N alphabetically"?

Alphabetical caps systematically bias toward species starting with "A" (you'd always get *Escherichia albertii* before *E. coli*). Quality-of-annotation caps (proteome size, BUSCO score, type-strain flag) bias toward well-studied taxa. A seeded random sample removes both biases and is still reproducible via the seed value.

## Caveats

- **`taxonomy_name` is a fuzzy field.** A query for `Escherichia somespecies` may match the genus and return an arbitrary *E. coli* proteome. Cell 6 mirrors the pipeline's own query, so a `True` here means "the pipeline will succeed in retrieving something for this name," not necessarily "this exact species exists in UniProt with its own proteome."
- **GTDB sub-clusters** like *Escherichia coli_A* are collapsed by default (`COLLAPSE_GTDB_LINEAGES = True`). Set to `False` if you specifically want GTDB's sub-species granularity surfaced as separate candidates.
- **The saved `.ipynb` is the audit artifact.** Cell outputs (GTDB row counts, candidate lists, UniProt responses, final picks) persist in the committed notebook. Run all cells before committing so the outputs reflect the most recent invocation.
- **No retry logic on UniProt failures.** If a UniProt request errors out, that species is marked `has_proteome=False` for this run. Re-run Cell 6 to retry.

## See also

- [Input format and taxonomic caveats](./input.md)
- [Running the pipeline](./running.md)
