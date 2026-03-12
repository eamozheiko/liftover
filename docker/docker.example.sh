#!/usr/bin/env bash
set -euo pipefail

# =========================
# User-configurable parameters
# =========================
DATA="/hdd-data/tesla_analysis/eamozheiko/data/test1"
OUTDIR="${DATA}/out_docker"

FASTA1="${DATA}/glyma.Wm82.gnm1.FCtY.genome_main.fna.gz"
FASTA2="${DATA}/GCA_030864155.1_ASM3086415v1_genomic.fna.gz"
VCF="${DATA}/glyma.Wm82.gnm1.div.Hu_Zhang_2020.SNPdata.vcf.gz"

THREADS=24
REF_CONSISTENT="false"

FROM_VERSION="glyma.Wm82.gnm1.FCtY"
TO_VERSION="GCA_030864155.1_ASM3086415v1"

ALIGN_IMAGE="liftover-align-chain:1.0"
LIFT_IMAGE="liftover-vcf:1.0"

# Host path mounted into containers
DOCKER_MOUNT_SRC="/hdd-data"
DOCKER_MOUNT_DST="/hdd-data"

# =========================
# Derived paths
# =========================
PAIR_NAME="${FROM_VERSION}_to_${TO_VERSION}"
PAIR_OUTDIR="${OUTDIR}/${PAIR_NAME}"

# =========================
# Checks
# =========================
for f in "${FASTA1}" "${FASTA2}" "${VCF}"; do
    if [[ ! -f "${f}" ]]; then
        echo "[ERROR] Input file not found: ${f}" >&2
        exit 1
    fi
done

mkdir -p "${PAIR_OUTDIR}"

echo "[INFO] DATA            : ${DATA}" >&2
echo "[INFO] OUTDIR          : ${PAIR_OUTDIR}" >&2
echo "[INFO] FASTA1          : ${FASTA1}" >&2
echo "[INFO] FASTA2          : ${FASTA2}" >&2
echo "[INFO] VCF             : ${VCF}" >&2
echo "[INFO] THREADS         : ${THREADS}" >&2
echo "[INFO] REF_CONSISTENT  : ${REF_CONSISTENT}" >&2
echo "[INFO] ALIGN_IMAGE     : ${ALIGN_IMAGE}" >&2
echo "[INFO] LIFT_IMAGE      : ${LIFT_IMAGE}" >&2

# =========================
# Step 1: alignment + chain
# =========================
echo "[INFO] Running align-chain container..." >&2

docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "${DOCKER_MOUNT_SRC}:${DOCKER_MOUNT_DST}" \
    "${ALIGN_IMAGE}" \
    "${FASTA1}" \
    "${FASTA2}" \
    "${PAIR_OUTDIR}" \
    "${THREADS}"

# =========================
# Step 2: VCF liftover
# =========================
echo "[INFO] Running liftover-vcf container..." >&2

docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "${DOCKER_MOUNT_SRC}:${DOCKER_MOUNT_DST}" \
    "${LIFT_IMAGE}" \
    "${PAIR_OUTDIR}/alignment/out.chain" \
    "${VCF}" \
    "${FASTA2}" \
    "${PAIR_OUTDIR}" \
    "${FROM_VERSION}" \
    "${TO_VERSION}" \
    "${REF_CONSISTENT}"

# =========================
# Final output
# =========================
echo "[INFO] Done." >&2
echo "Lifted VCF: ${PAIR_OUTDIR}/vcf/lifted.vcf.gz"
echo "Lifted TBI: ${PAIR_OUTDIR}/vcf/lifted.vcf.gz.tbi"
echo "Report:     ${PAIR_OUTDIR}/report/liftover_summary.tsv"
