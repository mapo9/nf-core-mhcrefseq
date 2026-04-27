# nf-core/mhcrefseq: Running the pipeline

> Development branch: `fasta_creation`. Make sure you are on that branch — `main` is still the unmodified nf-core template.

## What the pipeline does

Given a CSV of organism scientific names, `nf-core/mhcrefseq` builds a **per-sample, deduplicated protein FASTA** for downstream use with [mhcquant](https://nf-co.re/mhcquant):

1. **`INPUT_CHECK`** — validate the samplesheet with `bin/check_samplesheet.py`.
2. **`DOWNLOAD_FASTA`** — query UniProt REST for each organism's reference proteome and download the FASTA (with a genus-level fallback when no species-level reference proteome exists).
3. **`MERGE_FASTAS`** — concatenate all FASTAs belonging to the same `sample`.
4. **`CDHIT_CDHIT`** — cluster the merged FASTA with CD-HIT at 100 % identity to collapse duplicates across organisms.

For what `scientific_name` should look like (and what happens if you hand it a genus instead of a species), see [input.md](./input.md).

## Minimal run

```bash
nextflow run nf-core/mhcrefseq \
    --input ./samplesheet.csv \
    --outdir ./results \
    -profile docker
```

No `--genome` / `--fasta` — iGenomes references are not used by this pipeline.

## Running from a local clone

```bash
git checkout fasta_creation
nextflow run . \
    --input ./samplesheet.csv \
    --outdir ./results \
    -profile docker
```

## Conda activation in non-interactive shells

`conda activate` fails in non-interactive shells with `Run 'conda init' before 'conda activate'`. When invoking the pipeline from automation, wrappers, or CI, activate via an interactive bash:

```bash
bash -ic 'conda activate <env> && nextflow run . --input samplesheet.csv --outdir results -profile docker'
```

`conda run -n <env> …` also does not source activation hooks, so any tools installed by those hooks will not be on `PATH`.

## `-profile test` caveat

The shipped `conf/test.config` still points at a viralrecon fastq samplesheet inherited from the nf-core template. **`-profile test` does not currently exercise this pipeline end-to-end.** Use a real samplesheet with `scientific_name` rows instead until the test config is updated.

## Files produced in your working directory

```text
work/              # Nextflow staging. Safe to delete after a successful run.
<OUTDIR>/          # Results, location set by --outdir.
.nextflow_log      # Log from the last invocation.
```

## Using a params file

For repeated runs, put parameters in a YAML and pass it with `-params-file`:

```yaml title="params.yaml"
input: ./samplesheet.csv
outdir: ./results/
```

```bash
nextflow run nf-core/mhcrefseq -profile docker -params-file params.yaml
```

:::warning
Do not pass pipeline parameters via `-c <file>`. `-c` is for resource tuning and infrastructure tweaks only. Use `--<param>` on the CLI or `-params-file`.
:::

## Output layout

```text
results/
├── download/
│   └── <Organism>/
│       ├── <Organism>_reference.fasta        # downloaded UniProt proteome
│       └── failed_proteomes.txt              # always present — see input.md
├── merge/
│   └── <sample>_combined_ref.fasta           # all organisms for this sample concatenated
├── cdhit/
│   └── <sample>/
│       ├── <sample>_combined_ref.clustered.fasta       # deduplicated FASTA — use this downstream
│       └── <sample>_combined_ref.clustered.fasta.clstr # CD-HIT cluster assignments
└── pipeline_info/
    ├── samplesheet.valid.csv
    ├── *_versions.yml
    ├── execution_report_*.html
    ├── execution_timeline_*.html
    ├── execution_trace_*.txt
    └── pipeline_dag_*.html
```

The final reference FASTA per sample is `results/cdhit/<sample>/<sample>_combined_ref.clustered.fasta`.

CD-HIT is invoked with `-c 1 -G 1 -aS 0.9 -n 5 -d 0`: 100 % identity, global alignment, the shorter sequence must align over ≥90 % of its length, word size 5, keep full description in the cluster file.

## Profiles

Defined in `nextflow.config`. Multiple can be stacked (`-profile singularity,myinstitution`); later profiles override earlier ones.

Container / package profiles:

- `docker` — recommended on local machines.
- `singularity` — recommended on HPC. Local modules ship `oras://` Wave/Galaxy images.
- `podman`, `shifter`, `charliecloud`, `apptainer`.
- `conda`, `mamba` — last-resort fallbacks.

Other profiles:

- `arm` — adds `--platform=linux/amd64` to Docker for ARM hosts.
- `gitpod` — caps executor to 4 CPU / 8 GB.
- `debug` — dumps process hashes and disables cleanup.
- `test`, `test_full` — see the caveat above before using.

Institutional profiles are pulled in at runtime from [nf-core/configs](https://github.com/nf-core/configs).

Running without `-profile` expects every tool (`curl`, `cd-hit`, Python) to be on `PATH` — not recommended.

## `-resume`

Restart a run and reuse cached results for unchanged steps. Worth knowing because `DOWNLOAD_FASTA` is network-bound and `CDHIT_CDHIT` is the expensive step:

```bash
nextflow run . --input samplesheet.csv --outdir results -profile docker -resume
```

## Resource tuning

Default resources per process label (`conf/base.config`):

| Label             | CPU | Memory | Time | Used by                                                |
| ----------------- | --- | ------ | ---- | ------------------------------------------------------ |
| `process_single`  | 1   | 6 GB   | 4 h  | `SAMPLESHEET_CHECK`, `DOWNLOAD_FASTA`, `MERGE_FASTAS`  |
| `process_low`     | 2   | 12 GB  | 4 h  | —                                                      |
| `process_medium`  | 6   | 36 GB  | 8 h  | —                                                      |
| `process_high`    | 12  | 72 GB  | 16 h | `CDHIT_CDHIT`                                          |

CD-HIT's `-M` is set automatically to 80 % of `task.memory`.

If you're running on a small machine, cap the whole pipeline with `--max_cpus`, `--max_memory`, `--max_time`.

To override per-process resources without editing the repo, use a custom config passed with `-c`:

```groovy title="custom.config"
process {
    withName: CDHIT_CDHIT {
        cpus   = 8
        memory = '48.GB'
    }
}
```

## Custom tool arguments

Append extra arguments to a process via `ext.args` in your `-c` config. For example, to relax CD-HIT's identity threshold from 100 %:

```groovy
process {
    withName: CDHIT_CDHIT {
        ext.args = '-c 0.95'
    }
}
```

The base command in `modules/local/cdhit.nf` already sets several flags; duplicated flags go to whichever one CD-HIT's CLI parser takes last.

## Reproducibility notes

- Pin the pipeline version with `-r <tag>` (e.g. `-r 1.0dev`) so reruns use the exact same code.
- UniProt is always queried live — there is no release pinning in the current download step, so reruns can pick up newer proteome versions even with a pinned pipeline version.
- For **genus or higher-rank** inputs, UniProt's result order is not guaranteed stable. Two runs with the same samplesheet can produce different downloaded species. See [input.md](./input.md).

## Running in the background

`nextflow run -bg …` detaches Nextflow from your terminal (logs still go to `.nextflow.log`). `screen` / `tmux` / a scheduled cluster job are all fine alternatives.

## JVM memory

If the Nextflow driver hits Java OOMs (not the worker processes), cap the heap:

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

Add it to `~/.bashrc` or `~/.bash_profile`.

## See also

- [Input format and taxonomic caveats](./input.md)
