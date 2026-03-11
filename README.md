# VCF Liftover Workflow

A Snakemake workflow for lifting VCF coordinates from one genome assembly version to another.

The workflow performs:

1. Alignment of the source and target reference genomes with minimap2
2. Conversion of the alignment from PAF to CHAIN
3. Liftover of variants from the input VCF using CrossMap
4. Sorting and indexing of the lifted VCF
5. Generation of a summary report with variant counts and runtime statistics


## Workflow overview

Input:

- source reference genome FASTA
- target reference genome FASTA
- input VCF with variants on the source genome

Main output:

- lifted and indexed VCF on the target genome
- summary report with liftover statistics


## Requirements

This workflow requires the following software:

- [Snakemake](https://snakemake.readthedocs.io)
- [Conda](https://docs.conda.io)

Tools Used:

- [BCFtools](https://samtools.github.io/bcftools/)
- [Minimap2](https://github.com/lh3/minimap2)
- [paf2chain](https://github.com/AndreaGuarracino/paf2chain)
- [CrossMap](https://crossmap.readthedocs.io)
- [tabix](https://www.htslib.org/doc/tabix.html)


## Run workflow
```bash
snakemake --snakefile Snakefile --configfile config.yaml --cores 24 --use-conda --printshellcmds
```

## Output Structure

alignment/
- aln.paf
- out.chain

vcf/
- lifted.vcf.gz
- lifted.vcf.gz.tbi

report/
- liftover_summary.tsv

benchmark/
- rule benchmark files

Citation
--------

If you use Mixit in your research, the most relevant link to cite is:

* https://github.com/eamozheiko/liftover/
