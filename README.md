# SNP Liftover Workflow

A Snakemake workflow for lifting SNP/variant coordinates from one genome assembly version to another.

The workflow performs:

1. alignment of the source and target reference genomes with minimap2
2. conversion of the alignment from PAF to CHAIN
3. liftover of variants from the input VCF using CrossMap
4. sorting and indexing of the lifted VCF
5. generation of a summary report with variant counts and runtime statistics

---

## Workflow overview

Input:

- source reference genome FASTA
- target reference genome FASTA
- input VCF with variants on the source genome

Main output:

- lifted and indexed VCF on the target genome
- summary report with liftover statistics

---

## Requirements

- Snakemake
- Conda or Mamba

Tools used:

- bcftools
- minimap2
- paf2chain
- CrossMap
- tabix

---

## Run workflow

snakemake --snakefile Snakefile --configfile config.yaml --cores 24 --use-conda --printshellcmds

---

## Output

<outdir>/<from_version>_to_<to_version>/

alignment/
- aln.paf
- out.chain

vcf/
- lifted.vcf.gz
- lifted.vcf.gz.tbi

report/
- total_input_variants.txt
- liftover_summary.tsv

benchmark/
- rule benchmark files

---

## Summary report

The report contains:

- total_variant_count
- lifted_variant_count
- dropped_variant_count
- dropped_percent
- total_runtime_sec
- max_memory_mb

---

## Notes

Temporary files are created using `mktemp` and removed automatically.

The workflow uses `set -euo pipefail` to ensure robust shell execution.

---

## Cite

If you use this code please cite https://github.com/eamozheiko/liftover/
