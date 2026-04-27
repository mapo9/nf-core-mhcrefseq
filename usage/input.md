# nf-core/mhcrefseq: Input

> Development branch: `fasta_creation`. The `main` branch is still the unmodified nf-core template and does not match this document.

## What the pipeline takes in

A single CSV samplesheet with a header row and **two columns**:

```csv title="samplesheet.csv"
sample,scientific_name
ecoli_panel,Escherichia coli
ecoli_panel,Salmonella enterica
listeria_panel,Listeria monocytogenes
```

Pass it with `--input`:

```bash
--input '/path/to/samplesheet.csv'
```

| Column            | Description                                                                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`          | Sample identifier. Rows sharing the same value are grouped, and all their downloaded proteomes are merged and clustered into one output FASTA. Spaces are converted to `_`. |
| `scientific_name` | Organism name forwarded verbatim to UniProt's `taxonomy_name` search field. Use a **species binomial** (e.g. `Escherichia coli`) — see below.        |

No other columns, no fastq files, no genome references. `--genome` / `--fasta` are not used by this pipeline.

## Pick the right taxonomic rank — important

The `scientific_name` string is passed unchanged to a UniProt REST query of the form:

```
taxonomy_name:<your_string> AND proteome_type:reference
```

UniProt's `taxonomy_name` field matches **any node in the NCBI taxonomy tree** (species, genus, family, …), so the pipeline will not reject a higher-rank input. But the download logic is only correct for species binomials. Supplying a higher rank "works" in the sense that you get a FASTA out, but the FASTA may not be what you expect.

### What actually happens for each rank

| Input                                              | Result                                                                                                                                                                                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Species with a reference proteome** (`Escherichia coli`) | Species query finds the proteome, download succeeds. ✅ Intended path.                                                                                                                                                                                             |
| **Species without a reference proteome**           | The species query is empty or produces an empty FASTA → genus-level fallback runs, downloading the first reference proteome UniProt returns for the genus. The FASTA is saved under the **original species name** with no marker that it came from a related species. |
| **Bare genus** (`Escherichia`)                     | The species query returns **every** reference proteome in the genus (E. coli, E. albertii, E. fergusonii, …). The script downloads the **first one UniProt returns** and stops. You get one arbitrary species' proteome, filed under the genus name. The genus fallback does **not** trigger. |
| **Higher rank** (`Enterobacteriaceae`, `Bacteria`) | Same as bare genus, but even broader — one arbitrary proteome from anywhere in the clade.                                                                                                                                                                         |
| **Misspelled / unknown name**                      | Both queries return empty. No FASTA is produced, and the downstream `MERGE_FASTAS` and `CDHIT_CDHIT` steps fail because the expected output file doesn't exist.                                                                                                   |

### Why a genus input is risky

Two further gotchas when the input is a genus (or higher):

- **Order is not stable.** UniProt does not guarantee a fixed result order for this endpoint. Running the pipeline twice with the same genus input can return different species.
- **The filename lies.** Output is `<input>_reference.fasta`, so a genus input produces e.g. `Escherichia_reference.fasta` whose contents might be *E. albertii*. If species identity matters downstream, inspect FASTA headers.

### Recommendation

- Supply **species binomials** (`Escherichia coli`, `Listeria monocytogenes`, `Salmonella enterica`).
- If you want a genus-wide reference, enumerate every species you care about as separate rows under the same `sample`. For a small number of genera, the standalone notebook `bin/expand_genera.ipynb` automates this by drawing a seeded random sample of GTDB R226 species per genus — see [genus_expansion.md](./genus_expansion.md).
- If a species has no UniProt reference proteome, decide consciously whether the genus-level fallback is acceptable. The current pipeline does not warn you when it falls back.

## The `failed_proteomes.txt` log

Each organism's download directory contains a `failed_proteomes.txt`:

```
results/download/<Organism>/failed_proteomes.txt
```

This file is **written unconditionally** at the end of the download script, whether the download succeeded or not. It records the last proteome ID the script attempted, which may be useful for debugging but is not a reliable failure signal. Do not treat its presence as meaning a download failed.

## Known samplesheet-related template mismatches

Some files in the repo still reflect the original nf-core template and are out of date relative to the real `sample,scientific_name` format:

- `assets/schema_input.json` — still describes `fastq_1` / `fastq_2` columns. `nf-validation` will reject a valid samplesheet unless you pass `--validate_params false` or update the schema.
- `assets/samplesheet.csv` — still a fastq example.
- `conf/test.config` — points at a viralrecon fastq samplesheet URL, so `-profile test` does not currently exercise this pipeline end-to-end.

Update these when you are ready to ship a proper release.

## See also

- [Running the pipeline](./running.md)
- [Expanding genus inputs into a species panel](./genus_expansion.md)
