# =========================
# File: Snakefile
# Run with:
# snakemake --snakefile Snakefile --configfile config.yaml --cores 24 --use-conda --printshellcmds
# =========================

import os

configfile: "config.yaml"

DATA_DIR = config["data_dir"]
OUTDIR = config["outdir"]

FROM_VERSION = config["genomes"]["from_version"]
TO_VERSION = config["genomes"]["to_version"]

FASTA_FROM = config["reference"]["fasta_from"]
FASTA_TO = config["reference"]["fasta_to"]
VCF_IN = config["variants"]["vcf"]
THREADS_MINIMAP2 = int(config["resources"]["threads_minimap2"])
REF_CONSISTENT = bool(config["liftover"]["ref_consistent"])

PAIR_NAME = f"{FROM_VERSION}_to_{TO_VERSION}"

ALIGN_DIR = os.path.join(OUTDIR, PAIR_NAME, "alignment")
VCF_DIR = os.path.join(OUTDIR, PAIR_NAME, "vcf")
REPORT_DIR = os.path.join(OUTDIR, PAIR_NAME, "report")
LOG_DIR = os.path.join("logs", PAIR_NAME)
BENCH_DIR = os.path.join(OUTDIR, PAIR_NAME, "benchmark")

PAF = os.path.join(ALIGN_DIR, "aln.paf")
CHAIN = os.path.join(ALIGN_DIR, "out.chain")
LIFTED_VCF = os.path.join(VCF_DIR, "lifted.vcf.gz")
LIFTED_TBI = LIFTED_VCF + ".tbi"
REPORT = os.path.join(REPORT_DIR, "liftover_summary.tsv")
TOTAL_COUNT = os.path.join(REPORT_DIR, "total_input_variants.txt")

REF_CONSISTENT_FLAG = "--ref-consistent" if REF_CONSISTENT else ""

shell.executable("/bin/bash")
shell.prefix("set -euo pipefail; ")

rule all:
    input:
        LIFTED_VCF,
        LIFTED_TBI,
        TOTAL_COUNT,
        REPORT

rule count_input_variants:
    input:
        vcf=VCF_IN
    output:
        TOTAL_COUNT
    log:
        os.path.join(LOG_DIR, "count_input_variants.log")
    benchmark:
        os.path.join(BENCH_DIR, "count_input_variants.tsv")
    conda:
        "envs/count_input_variants.yaml"
    message:
        "Counting total input variants"
    shell:
        r"""
        mkdir -p "{REPORT_DIR}" "{LOG_DIR}" "{BENCH_DIR}"
        tmpfile=$(mktemp "{REPORT_DIR}/total_input_variants_tmp.XXXXXX")

        bcftools view -H "{input.vcf}" 2>> "{log}" | wc -l > "$tmpfile"

        mv "$tmpfile" "{output}"
        """

rule minimap2_align:
    input:
        fasta_from=FASTA_FROM,
        fasta_to=FASTA_TO
    output:
        paf=PAF
    threads:
        THREADS_MINIMAP2
    log:
        os.path.join(LOG_DIR, "minimap2_align.log")
    benchmark:
        os.path.join(BENCH_DIR, "minimap2_align.tsv")
    conda:
        "envs/minimap2_align.yaml"
    message:
        "Running minimap2 assembly alignment"
    shell:
        r"""
        mkdir -p "{ALIGN_DIR}" "{LOG_DIR}" "{BENCH_DIR}"
        tmpdir=$(mktemp -d "{ALIGN_DIR}/minimap2_tmp.XXXXXX")
        trap 'rm -rf "$tmpdir"' EXIT

        /usr/bin/time -v -o "{log}.time" \
            minimap2 \
                -x asm5 \
                -c \
                -t {threads} \
                "{input.fasta_from}" \
                "{input.fasta_to}" \
                > "$tmpdir/aln.paf" 2> "{log}"

        mv "$tmpdir/aln.paf" "{output.paf}"
        """

rule paf_to_chain:
    input:
        paf=PAF
    output:
        chain=CHAIN
    log:
        os.path.join(LOG_DIR, "paf_to_chain.log")
    benchmark:
        os.path.join(BENCH_DIR, "paf_to_chain.tsv")
    conda:
        "envs/paf_to_chain.yaml"
    message:
        "Converting PAF to CHAIN"
    shell:
        r"""
        mkdir -p "{ALIGN_DIR}" "{LOG_DIR}" "{BENCH_DIR}"
        tmpdir=$(mktemp -d "{ALIGN_DIR}/chain_tmp.XXXXXX")
        trap 'rm -rf "$tmpdir"' EXIT

        paf2chain -i "{input.paf}" > "$tmpdir/out.chain" 2> "{log}"

        mv "$tmpdir/out.chain" "{output.chain}"
        """

rule liftover_vcf:
    input:
        chain=CHAIN,
        vcf=VCF_IN,
        fasta_to=FASTA_TO
    output:
        vcf=LIFTED_VCF,
        tbi=LIFTED_TBI
    params:
        ref_consistent_flag=REF_CONSISTENT_FLAG
    log:
        os.path.join(LOG_DIR, "liftover_vcf.log")
    benchmark:
        os.path.join(BENCH_DIR, "liftover_vcf.tsv")
    conda:
        "envs/liftover_vcf.yaml"
    message:
        "Running CrossMap liftover"
    shell:
        r"""
        mkdir -p "{VCF_DIR}" "{LOG_DIR}" "{BENCH_DIR}"
        tmpdir=$(mktemp -d "{VCF_DIR}/crossmap_tmp.XXXXXX")
        trap 'rm -rf "$tmpdir"' EXIT

        CrossMap vcf \
            {params.ref_consistent_flag} \
            --chromid s \
            "{input.chain}" \
            "{input.vcf}" \
            "{input.fasta_to}" \
            "$tmpdir/lifted.unsorted.vcf" \
            > "{log}" 2>&1

        bcftools sort \
            "$tmpdir/lifted.unsorted.vcf" \
            -Oz \
            -o "$tmpdir/lifted.vcf.gz" \
            >> "{log}" 2>&1

        tabix -f -p vcf "$tmpdir/lifted.vcf.gz" >> "{log}" 2>&1

        mv "$tmpdir/lifted.vcf.gz" "{output.vcf}"
        mv "$tmpdir/lifted.vcf.gz.tbi" "{output.tbi}"
        """

rule report:
    input:
        total_count=TOTAL_COUNT,
        lifted_vcf=LIFTED_VCF,
        benchmarks=expand(
            os.path.join(BENCH_DIR, "{r}.tsv"),
            r=["count_input_variants", "minimap2_align", "paf_to_chain", "liftover_vcf"]
        )
    output:
        REPORT
    log:
        os.path.join(LOG_DIR, "liftover_report.log")
    benchmark:
        os.path.join(BENCH_DIR, "liftover_report.tsv")
    conda:
        "envs/report.yaml"
    message:
        "Generating liftover summary report"
    shell:
        r"""
        mkdir -p "{REPORT_DIR}" "{LOG_DIR}" "{BENCH_DIR}"
        tmpfile=$(mktemp "{REPORT_DIR}/report_tmp.XXXXXX")

        total_variants=$(cat "{input.total_count}")
        lifted_variants=$(bcftools view -H "{input.lifted_vcf}" 2>> "{log}" | wc -l)
        dropped_variants=$((total_variants - lifted_variants))

        dropped_percent=$(awk -v total="$total_variants" -v dropped="$dropped_variants" 'BEGIN {{
            if (total == 0) printf "0.00";
            else printf "%.2f", (dropped / total) * 100
        }}')

        total_runtime=$(awk 'NR>1 {{sum+=$1}} END {{printf "%.2f", sum}}' {input.benchmarks})
        max_memory=$(awk 'FNR>1 && $3+0 > max {{max=$3+0}} END {{printf "%.2f", max}}' {input.benchmarks})

        {{
            echo -e "from_version\tto_version\tref_consistent\ttotal_variant_count\tlifted_variant_count\tdropped_variant_count\tdropped_percent\ttotal_runtime_sec\tmax_memory_mb"
            echo -e "{FROM_VERSION}\t{TO_VERSION}\t{REF_CONSISTENT}\t${{total_variants}}\t${{lifted_variants}}\t${{dropped_variants}}\t${{dropped_percent}}\t${{total_runtime}}\t${{max_memory}}"
        }} > "$tmpfile"

        mv "$tmpfile" "{output}"
        """

