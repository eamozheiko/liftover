#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: run-align-chain.sh <fasta_from> <fasta_to> <outdir> <threads>" >&2
    exit 1
fi

FASTA_FROM="$1"
FASTA_TO="$2"
OUTDIR="$3"
THREADS="$4"

ALIGN_DIR="${OUTDIR}/alignment"
LOG_DIR="${OUTDIR}/logs"
BENCH_DIR="${OUTDIR}/benchmark"

MINIMAP2="/opt/conda/envs/alignchain/bin/minimap2"
PAF2CHAIN="/opt/conda/envs/alignchain/bin/paf2chain"

mkdir -p "${ALIGN_DIR}" "${LOG_DIR}" "${BENCH_DIR}"

tmpdir="$(mktemp -d "${ALIGN_DIR}/align_tmp.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

start_ts=$(date +%s)

echo "[INFO] Running minimap2..." >&2
"${MINIMAP2}" \
    -x asm5 \
    -c \
    -t "${THREADS}" \
    "${FASTA_FROM}" \
    "${FASTA_TO}" \
    > "${tmpdir}/aln.paf" \
    2> >(tee "${LOG_DIR}/minimap2_align.log" >&2)

echo "[INFO] minimap2 finished" >&2
mv "${tmpdir}/aln.paf" "${ALIGN_DIR}/aln.paf"

echo "[INFO] Running paf2chain..." >&2
"${PAF2CHAIN}" -i "${ALIGN_DIR}/aln.paf" \
    > "${tmpdir}/out.chain" \
    2> >(tee "${LOG_DIR}/paf_to_chain.log" >&2)

echo "[INFO] paf2chain finished" >&2
mv "${tmpdir}/out.chain" "${ALIGN_DIR}/out.chain"

end_ts=$(date +%s)
runtime_sec=$((end_ts - start_ts))

{
    echo -e "step\truntime_sec"
    echo -e "align_chain\t${runtime_sec}"
} > "${BENCH_DIR}/align_chain_runtime.tsv"

echo "[INFO] Done." >&2
echo "[INFO] PAF:   ${ALIGN_DIR}/aln.paf" >&2
echo "[INFO] CHAIN: ${ALIGN_DIR}/out.chain" >&2
echo "[INFO] Runtime (s): ${runtime_sec}" >&2
