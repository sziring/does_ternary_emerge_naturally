#!/usr/bin/env bash
set -euo pipefail

# Where to stash logs and CSVs
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTDIR="runs/${STAMP}"
mkdir -p "${OUTDIR}"

# Energy knobs (can tweak per-run or export beforehand)
export ENERGY_HOLD_SCALE="${ENERGY_HOLD_SCALE:-1.0}"
export ENERGY_SWITCH_SCALE="${ENERGY_SWITCH_SCALE:-1.0}"
export LAMBDA_ENERGY="${LAMBDA_ENERGY:-1.0}"

BIN="target/release/ai-ground-up"

# Build once, release mode
echo "==> Building (release)…"
cargo build --release >/dev/null

echo
echo "AI Ground-Up Computing Research"
echo "================================"
echo "Using $(numactl --hardware >/dev/null 2>&1 && numactl --hardware | grep 'cpus' | wc -w || echo 'N/A') CPU cores (reported by system)"
echo
echo "energy_knobs: ENERGY_HOLD_SCALE=${ENERGY_HOLD_SCALE} ENERGY_SWITCH_SCALE=${ENERGY_SWITCH_SCALE} LAMBDA_ENERGY=${LAMBDA_ENERGY}"
echo "Results + CSVs will be saved under: ${OUTDIR}"
echo

run() {
  local name="$1"; shift
  local cmd="${BIN} sweep --sweep-fast $* --sweep-stdout=summary"
  local log="${OUTDIR}/${name}.txt"
  local csv="${OUTDIR}/${name}.csv"

  echo "------------------------------------------------------------"
  echo "Experiment: ${name}"
  echo "Command/s used: ${cmd} --sweep-csv=${csv}"
  echo "------------------------------------------------------------"
  # Run and capture summary to .txt while also showing on screen
  ${cmd} --sweep-csv="${csv}" | tee "${log}"
  echo
}

### SUITE ###

# 0) Sanity: binary-only across mild σ + energy grid (should be all B)
run "binary_only_sigma_0.1_0.3_0.5_ez0.5_ea1.0" \
  --sweep-allowed=binary_only \
  --sweep-sigmas=0.1,0.3,0.5 \
  --sweep-energy-zero=0.5 \
  --sweep-energy-abs1=1.0

# 1) Ternary-friendly: discrete only (step, schmitt, quantizer), 3-level quantizer
run "ternary_friendly_ez0.1_ea1.2" \
  --sweep-allowed=discrete_only \
  --sweep-quant-levels=3 \
  --sweep-sigmas=0.1,0.3 \
  --sweep-energy-zero=0.1 \
  --sweep-energy-abs1=1.2

# 2) Ternary-friendly variant: make 0 cheap, ±1 a bit cheaper than (1)
run "ternary_friendly_ez2.0_ea0.8" \
  --sweep-allowed=discrete_only \
  --sweep-quant-levels=3 \
  --sweep-sigmas=0.1,0.3 \
  --sweep-energy-zero=2.0 \
  --sweep-energy-abs1=0.8

# 3) Phase grid with higher noise (0.5,1.0,2.0) across energy grid
run "discrete_only_high_sigma_grid" \
  --sweep-allowed=discrete_only \
  --sweep-quant-levels=3 \
  --sweep-sigmas=0.5,1.0,2.0 \
  --sweep-energy-zero=0.2,0.8 \
  --sweep-energy-abs1=1.0,1.5

# 4) Quaternary probe: discrete-only, quant_levels=4, low σ
run "quaternary_probe_sig_0.05_0.1_ez1.0_ea1.0" \
  --sweep-allowed=discrete_only \
  --sweep-quant-levels=4 \
  --sweep-sigmas=0.05,0.1 \
  --sweep-energy-zero=1.0 \
  --sweep-energy-abs1=1.0

# 5) Bias test: force target=2 with mismatch penalty
run "target2_bias_vs_natural" \
  --sweep-allowed=discrete_only \
  --sweep-quant-levels=3 \
  --sweep-sigmas=0.1,0.3 \
  --sweep-target-states=2 \
  --sweep-mismatch-penalty=1.2

# 6) Unbiased counterpart (no target; should show what emerges naturally)
run "no_target_bias_control" \
  --sweep-allowed=discrete_only \
  --sweep-quant-levels=3 \
  --sweep-sigmas=0.1,0.3

# 7) Pathological control: “relu-only” (expect nonstandard multi-bin artifacts at high σ)
run "relu_only_sigma_0.1_0.3_0.5" \
  --sweep-allowed=relu_only \
  --sweep-sigmas=0.1,0.3,0.5 \
  --sweep-energy-zero=0.5 \
  --sweep-energy-abs1=1.0

echo "============================================================"
echo "Suite complete."
echo "Folder with summaries/CSVs: ${OUTDIR}"
echo "Tip: for a quick overview: grep -R \"Summary (winners by cell)\" ${OUTDIR}"

