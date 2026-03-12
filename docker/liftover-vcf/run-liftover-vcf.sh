#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
    echo "Usage: run-liftover-vcf.sh <chain> <input_vcf> <target_fasta> <outdir> <from_version> <to_version> <ref_consistent>" >&2
    exit 1
fi

CHAIN="$1"
INPUT_VCF="$2"
TARGET_FASTA="$3"
OUTDIR="$4"
FROM_VERSION="$5"
TO_VERSION="$6"
REF_CONSISTENT="$7"

VCF_DIR="${OUTDIR}/vcf"
REPORT_DIR="${OUTDIR}/report"
LOG_DIR="${OUTDIR}/logs"
BENCH_DIR="${OUTDIR}/benchmark"

mkdir -p "${VCF_DIR}" "${REPORT_DIR}" "${LOG_DIR}" "${BENCH_DIR}"

tmpdir="$(mktemp -d "${VCF_DIR}/liftover_tmp.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

start_ts=$(date +%s)

CROSSMAP_ARGS=()
if [[ "${REF_CONSISTENT}" == "true" || "${REF_CONSISTENT}" == "True" ]]; then
    CROSSMAP_ARGS+=(--ref-consistent)
fi

echo "[INFO] Running CrossMap..." >&2
CrossMap vcf \
    "${CROSSMAP_ARGS[@]}" \
    --chromid s \
    "${CHAIN}" \
    "${INPUT_VCF}" \
    "${TARGET_FASTA}" \
    "${tmpdir}/lifted.unsorted.vcf" \
    2> >(tee "${LOG_DIR}/liftover_vcf.log" >&2)

echo "[INFO] Sorting lifted VCF..." >&2
bcftools sort \
    "${tmpdir}/lifted.unsorted.vcf" \
    -Oz \
    -o "${tmpdir}/lifted.vcf.gz" \
    2> >(tee "${LOG_DIR}/bcftools_sort.log" >&2)

echo "[INFO] Indexing lifted VCF..." >&2
tabix -f -p vcf "${tmpdir}/lifted.vcf.gz" \
    2> >(tee "${LOG_DIR}/tabix.log" >&2)

mv "${tmpdir}/lifted.vcf.gz" "${VCF_DIR}/lifted.vcf.gz"
mv "${tmpdir}/lifted.vcf.gz.tbi" "${VCF_DIR}/lifted.vcf.gz.tbi"

echo "[INFO] Counting variants..." >&2
total_variants=$(bcftools view -H "${INPUT_VCF}" | wc -l)
lifted_variants=$(bcftools view -H "${VCF_DIR}/lifted.vcf.gz" | wc -l)
dropped_variants=$((total_variants - lifted_variants))

dropped_percent=$(awk -v total="${total_variants}" -v dropped="${dropped_variants}" 'BEGIN {
    if (total == 0) {
        printf "0.00"
    } else {
        printf "%.2f", (dropped / total) * 100
    }
}')

end_ts=$(date +%s)
runtime_sec=$((end_ts - start_ts))

{
    echo -e "from_version\tto_version\tref_consistent\ttotal_variant_count\tlifted_variant_count\tdropped_variant_count\tdropped_percent\ttotal_runtime_sec"
    echo -e "${FROM_VERSION}\t${TO_VERSION}\t${REF_CONSISTENT}\t${total_variants}\t${lifted_variants}\t${dropped_variants}\t${dropped_percent}\t${runtime_sec}"
} > "${REPORT_DIR}/liftover_summary.tsv"

{
    echo -e "step\truntime_sec"
    echo -e "liftover_vcf\t${runtime_sec}"
} > "${BENCH_DIR}/liftover_vcf_runtime.tsv"

echo "[INFO] Done." >&2
echo "[INFO] Lifted VCF: ${VCF_DIR}/lifted.vcf.gz" >&2
echo "[INFO] Report:     ${REPORT_DIR}/liftover_summary.tsv" >&2
echo "[INFO] Runtime (s): ${runtime_sec}" >&2
