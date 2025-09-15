#!/bin/bash

# Complete Counterfactual Computing Validation Suite
# Implements ChatGPT's full preregistered protocol

set -e  

# Configuration
BINARY="./target/release/ai-ground-up"
RESULTS_DIR="validation_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${RESULTS_DIR}/${TIMESTAMP}"

# Full experimental parameters (ChatGPT's roadmap)
SEEDS=100  # Full statistical power
CORES=$(nproc)

echo "=== COMPLETE COUNTERFACTUAL COMPUTING VALIDATION ==="
echo "Implementing ChatGPT's preregistered protocol"
echo "Timestamp: ${TIMESTAMP}"
echo "Results directory: ${RUN_DIR}"
echo "Using ${CORES} CPU cores"
echo "Seeds per condition: ${SEEDS}"
echo

# Create results directory
mkdir -p "${RUN_DIR}"
cd "$(dirname "$0")"

# Build the release binary
echo "Building release binary..."
cargo build --release
echo

# Verify binary exists
if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Binary not found at ${BINARY}"
    exit 1
fi

# Function to run a sweep and log progress
run_test() {
    local name="$1"
    local cmd="$2"
    local output_file="${RUN_DIR}/${name}.log"
    
    echo "=== Running: ${name} ==="
    echo "Command: ${cmd}"
    echo "Output: ${output_file}"
    echo "Started: $(date)"
    
    # Record metadata
    echo "# Command: ${cmd}" > "${output_file}"
    echo "# Started: $(date)" >> "${output_file}"
    echo "# Git commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')" >> "${output_file}"
    echo "# Seeds: ${SEEDS}" >> "${output_file}"
    echo >> "${output_file}"
    
    # Run the command
    eval "${cmd}" >> "${output_file}" 2>&1
    
    echo "Completed: $(date)"
    echo "Log saved to: ${output_file}"
    echo
}

# A) CONTINUOUS-ONLY TESTS (H1/H2) - Full matrix
echo "=== PHASE A: Continuous-only validation (H1/H2) ==="
echo "Testing ternary emergence in pure continuous systems"

for energy_model in base leak; do
    for gens in 120 480; do
        name="cont_${energy_model}_g${gens}"
        cmd="${BINARY} sweep \
            --sweep-allowed=continuous_only \
            --sweep-sigmas=0.05,0.1,0.2,0.3,0.5,1.0 \
            --sweep-energy-zero=0.0,0.2,0.8,2.0,5.0,10.0 \
            --sweep-energy-abs1=1.0 \
            --sweep-gens=${gens} --sweep-pop=40 --sweep-seeds=${SEEDS} \
            --energy-model=${energy_model} \
            --sweep-stdout=summary"
        
        run_test "${name}" "${cmd}"
    done
done

# B) BINARY-ONLY TESTS (H3) - Constraint validation
echo "=== PHASE B: Binary-only validation (H3) ==="
echo "Testing binary dominance under binary-only constraints"

for gens in 120 480; do
    name="binary_g${gens}"
    cmd="${BINARY} sweep \
        --sweep-allowed=binary_only \
        --sweep-sigmas=0.05,0.1,0.2,0.3,0.5,1.0 \
        --sweep-energy-zero=0.0,0.2,0.8,2.0,5.0,10.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=${gens} --sweep-pop=40 --sweep-seeds=${SEEDS} \
        --energy-model=base \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# C) DISCRETE-ONLY TESTS - Ternary baseline with quantizers
echo "=== PHASE C: Discrete-only validation ==="
echo "Testing ternary emergence with discrete attractors"

for gens in 120 480; do
    name="discrete_g${gens}"
    cmd="${BINARY} sweep \
        --sweep-allowed=discrete_only \
        --sweep-sigmas=0.05,0.1,0.2,0.3,0.5,1.0 \
        --sweep-energy-zero=0.0,0.2,0.8,2.0,5.0,10.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=${gens} --sweep-pop=40 --sweep-seeds=${SEEDS} \
        --energy-model=base \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# D) ENERGY MODEL ABLATION (H5) - Implementation bias testing
echo "=== PHASE D: Energy model ablation (H5) ==="
echo "Testing robustness across different energy models"

for energy_model in base asym leak; do
    name="ablation_${energy_model}"
    cmd="${BINARY} sweep \
        --sweep-allowed=continuous_only \
        --sweep-sigmas=0.1,0.3,0.5 \
        --sweep-energy-zero=0.2,2.0,10.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=120 --sweep-pop=40 --sweep-seeds=${SEEDS} \
        --energy-model=${energy_model} \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# E) CONVERGENCE ANALYSIS - Population and generation effects
echo "=== PHASE E: Convergence analysis ==="
echo "Testing population size and generation depth effects"

# Small vs large population
for pop in 40 200; do
    name="convergence_pop${pop}"
    cmd="${BINARY} sweep \
        --sweep-allowed=continuous_only \
        --sweep-sigmas=0.1,0.3 \
        --sweep-energy-zero=0.2,2.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=120 --sweep-pop=${pop} --sweep-seeds=${SEEDS} \
        --energy-model=base \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# Extended generations for deep search
name="convergence_deep"
cmd="${BINARY} sweep \
    --sweep-allowed=continuous_only \
    --sweep-sigmas=0.1,0.3 \
    --sweep-energy-zero=0.2,10.0 \
    --sweep-energy-abs1=1.0 \
    --sweep-gens=1000 --sweep-pop=40 --sweep-seeds=50 \
    --energy-model=base \
    --sweep-stdout=summary"

run_test "${name}" "${cmd}"

# F) COMPARATIVE ANALYSIS - All constraint types under identical conditions
echo "=== PHASE F: Comparative analysis ==="
echo "Direct comparison of all constraint types"

for allowed in continuous_only binary_only discrete_only; do
    name="compare_${allowed}"
    cmd="${BINARY} sweep \
        --sweep-allowed=${allowed} \
        --sweep-sigmas=0.1,0.3,0.5 \
        --sweep-energy-zero=0.2,2.0,10.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=120 --sweep-pop=40 --sweep-seeds=${SEEDS} \
        --energy-model=base \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# Generate comprehensive analysis
echo "=== Generating comprehensive analysis ==="
analysis_script="${RUN_DIR}/comprehensive_analysis.py"

cat > "${analysis_script}" << 'EOF'
#!/usr/bin/env python3
import re
import glob
import os
from pathlib import Path
from collections import defaultdict, Counter
import json

def parse_csv_rows_from_log(log_content):
    """Extract CSV_ROW lines and metadata from log output"""
    rows = []
    metadata = {}
    
    # Extract metadata
    for line in log_content.split('\n'):
        if line.startswith('# '):
            if 'Seeds:' in line:
                metadata['seeds'] = int(line.split()[-1])
            elif 'Command:' in line:
                metadata['command'] = line[2:].strip()
        elif 'gens=' in line and 'pop=' in line:
            # Parse experiment parameters
            parts = line.split()
            for part in parts:
                if '=' in part:
                    key, value = part.split('=', 1)
                    try:
                        metadata[key] = int(value) if value.isdigit() else value
                    except:
                        metadata[key] = value
        elif line.startswith('CSV_ROW,'):
            # Parse data rows
            parts = line.split(',')
            if len(parts) >= 5:
                try:
                    sigma = float(parts[1])
                    energy_zero = float(parts[2])
                    energy_abs1 = float(parts[3])
                    n_states = int(parts[4])
                    
                    # Extract additional info
                    remainder = ','.join(parts[5:])
                    hysteresis = '[H]' in remainder
                    consensus_match = re.search(r'\((\d+)/(\d+)\)', remainder)
                    consensus = None
                    if consensus_match:
                        consensus = (int(consensus_match.group(1)), int(consensus_match.group(2)))
                    
                    rows.append({
                        'sigma': sigma,
                        'energy_zero': energy_zero,
                        'energy_abs1': energy_abs1,
                        'n_states': n_states,
                        'hysteresis': hysteresis,
                        'consensus': consensus
                    })
                except (ValueError, IndexError):
                    continue
    
    return rows, metadata

def calculate_confidence_interval(successes, trials, confidence=0.95):
    """Calculate binomial confidence interval"""
    if trials == 0:
        return (0, 0)
    
    p = successes / trials
    z = 1.96  # 95% confidence
    margin = z * (p * (1 - p) / trials) ** 0.5
    return (max(0, p - margin), min(1, p + margin))

def analyze_results():
    """Comprehensive analysis following ChatGPT's protocol"""
    log_files = glob.glob('*.log')
    
    if not log_files:
        print("No log files found")
        return
    
    # Parse all results
    all_data = []
    experiments = {}
    
    for log_file in log_files:
        with open(log_file, 'r') as f:
            content = f.read()
        
        rows, metadata = parse_csv_rows_from_log(content)
        experiment_name = Path(log_file).stem
        experiments[experiment_name] = {'data': rows, 'metadata': metadata}
        
        for row in rows:
            row['experiment'] = experiment_name
            all_data.append(row)
    
    if not all_data:
        print("No valid data found")
        return
    
    print("=== COMPREHENSIVE VALIDATION RESULTS ===")
    print(f"Total experiments: {len(log_files)}")
    print(f"Total parameter combinations: {len(all_data)}")
    print(f"Average seeds per combination: {sum(r['consensus'][1] for r in all_data if r['consensus']) / len([r for r in all_data if r['consensus']]):.1f}")
    print()
    
    # Overall state distribution
    print("=== OVERALL STATE DISTRIBUTION ===")
    state_counts = Counter(row['n_states'] for row in all_data)
    hysteresis_count = sum(1 for row in all_data if row['hysteresis'])
    total = len(all_data)
    
    for states in sorted(state_counts.keys()):
        count = state_counts[states]
        pct = 100 * count / total
        state_name = {0: 'Analog', 1: 'Single', 2: 'Binary', 3: 'Ternary', 4: 'Quaternary'}.get(states, f'{states}-state')
        print(f"{state_name:10}: {count:4d} ({pct:5.1f}%)")
    
    print(f"Hysteresis : {hysteresis_count:4d} ({100*hysteresis_count/total:5.1f}%)")
    print()
    
    # Hypothesis testing with confidence intervals
    print("=== HYPOTHESIS VALIDATION (with 95% CIs) ===")
    
    # H1: Continuous-only ternary prevalence
    cont_data = [r for r in all_data if 'cont_' in r['experiment']]
    if cont_data:
        low_noise = [r for r in cont_data if r['sigma'] <= 0.3]
        if low_noise:
            ternary_count = sum(1 for r in low_noise if r['n_states'] == 3)
            binary_count = sum(1 for r in low_noise if r['n_states'] == 2)
            total_low = len(low_noise)
            
            ternary_rate = ternary_count / total_low
            binary_rate = binary_count / total_low
            
            ternary_ci = calculate_confidence_interval(ternary_count, total_low)
            binary_ci = calculate_confidence_interval(binary_count, total_low)
            
            print(f"H1 - Continuous-only at low noise (σ≤0.3):")
            print(f"     Ternary: {ternary_count}/{total_low} ({ternary_rate:.3f}) [95% CI: {ternary_ci[0]:.3f}-{ternary_ci[1]:.3f}]")
            print(f"     Binary:  {binary_count}/{total_low} ({binary_rate:.3f}) [95% CI: {binary_ci[0]:.3f}-{binary_ci[1]:.3f}]")
            print(f"     Advantage: {ternary_rate - binary_rate:+.3f}")
            print(f"     Result: {'PASS' if ternary_rate > binary_rate and ternary_ci[0] > binary_ci[1] else 'FAIL'}")
            print()
    
    # H2: Energy zero sensitivity
    cont_base = [r for r in all_data if 'cont_base' in r['experiment'] and r['sigma'] == 0.1]
    if cont_base:
        print("H2 - Energy zero sensitivity (σ=0.1, continuous-only):")
        energy_groups = defaultdict(list)
        for row in cont_base:
            energy_groups[row['energy_zero']].append(row)
        
        prev_ternary_rate = None
        declining = True
        for energy_zero in sorted(energy_groups.keys()):
            rows = energy_groups[energy_zero]
            ternary_count = sum(1 for r in rows if r['n_states'] == 3)
            total = len(rows)
            ternary_rate = ternary_count / total if total > 0 else 0
            ci = calculate_confidence_interval(ternary_count, total)
            
            print(f"     E₀={energy_zero:4.1f}: {ternary_count}/{total} ({ternary_rate:.3f}) [95% CI: {ci[0]:.3f}-{ci[1]:.3f}]")
            
            if prev_ternary_rate is not None and ternary_rate > prev_ternary_rate:
                declining = False
            prev_ternary_rate = ternary_rate
        
        print(f"     Declining trend: {'YES' if declining else 'NO'}")
        print(f"     Result: {'PASS' if declining else 'FAIL'}")
        print()
    
    # H3: Binary-only dominance
    binary_data = [r for r in all_data if 'binary_' in r['experiment']]
    if binary_data:
        binary_count = sum(1 for r in binary_data if r['n_states'] == 2)
        total_binary = len(binary_data)
        binary_rate = binary_count / total_binary
        ci = calculate_confidence_interval(binary_count, total_binary)
        
        print(f"H3 - Binary-only constraint:")
        print(f"     Binary: {binary_count}/{total_binary} ({binary_rate:.3f}) [95% CI: {ci[0]:.3f}-{ci[1]:.3f}]")
        print(f"     Target: ≥0.90")
        print(f"     Result: {'PASS' if ci[0] >= 0.90 else 'FAIL'}")
        print()
    
    # Generation effects analysis
    print("=== CONVERGENCE ANALYSIS ===")
    
    generation_comparisons = []
    for exp_base in ['cont_base', 'cont_leak', 'binary', 'discrete']:
        g120_data = [r for r in all_data if f'{exp_base}_g120' in r['experiment']]
        g480_data = [r for r in all_data if f'{exp_base}_g480' in r['experiment']]
        
        if g120_data and g480_data:
            def get_rates(data):
                total = len(data)
                ternary = sum(1 for r in data if r['n_states'] == 3)
                binary = sum(1 for r in data if r['n_states'] == 2)
                return ternary/total, binary/total
            
            t120, b120 = get_rates(g120_data)
            t480, b480 = get_rates(g480_data)
            
            print(f"{exp_base:12}: 120gen T={t120:.3f} B={b120:.3f} | 480gen T={t480:.3f} B={b480:.3f} | ΔT={t480-t120:+.3f}")
            generation_comparisons.append((exp_base, t480-t120, b480-b120))
    
    # Population effects
    pop_data = [r for r in all_data if 'convergence_pop' in r['experiment']]
    if pop_data:
        print("\nPopulation size effects:")
        for pop in [40, 200]:
            subset = [r for r in pop_data if f'pop{pop}' in r['experiment']]
            if subset:
                ternary_rate = sum(1 for r in subset if r['n_states'] == 3) / len(subset)
                print(f"     Pop {pop:3d}: Ternary rate {ternary_rate:.3f} (n={len(subset)})")
    
    print()
    
    # Energy model robustness
    print("=== ENERGY MODEL ROBUSTNESS ===")
    ablation_data = [r for r in all_data if 'ablation_' in r['experiment']]
    if ablation_data:
        energy_models = defaultdict(list)
        for row in ablation_data:
            model = row['experiment'].split('_')[1]
            energy_models[model].append(row)
        
        for model in sorted(energy_models.keys()):
            rows = energy_models[model]
            ternary_count = sum(1 for r in rows if r['n_states'] == 3)
            binary_count = sum(1 for r in rows if r['n_states'] == 2)
            total = len(rows)
            
            ternary_rate = ternary_count / total
            binary_rate = binary_count / total
            ternary_ci = calculate_confidence_interval(ternary_count, total)
            
            print(f"     {model:4}: T={ternary_count:2d}/{total} ({ternary_rate:.3f}) B={binary_count:2d}/{total} ({binary_rate:.3f}) [T CI: {ternary_ci[0]:.3f}-{ternary_ci[1]:.3f}]")
    
    print()
    
    # Summary statistics
    print("=== EXPERIMENT SUMMARY ===")
    for log_file in sorted(log_files):
        exp_name = Path(log_file).stem
        if exp_name in experiments:
            data = experiments[exp_name]['data']
            metadata = experiments[exp_name]['metadata']
            size_kb = os.path.getsize(log_file) / 1024
            
            gens = metadata.get('gens', 'unknown')
            pop = metadata.get('pop', 'unknown')
            seeds = metadata.get('seeds', 'unknown')
            
            print(f"{exp_name:20} ({size_kb:6.1f} KB): {len(data):2d} conditions, {gens}gen/{pop}pop/{seeds}seeds")
    
    # Save summary data
    summary_data = {
        'total_experiments': len(log_files),
        'total_combinations': len(all_data),
        'state_distribution': dict(state_counts),
        'hysteresis_rate': hysteresis_count / total,
        'experiments': {name: {'conditions': len(exp['data']), 'metadata': exp['metadata']} 
                      for name, exp in experiments.items()}
    }
    
    with open('validation_summary.json', 'w') as f:
        json.dump(summary_data, f, indent=2)
    
    print(f"\nDetailed summary saved to: validation_summary.json")

if __name__ == '__main__':
    analyze_results()
EOF

chmod +x "${analysis_script}"

# Run comprehensive analysis
echo "Running comprehensive analysis..."
cd "${RUN_DIR}"
python3 "${analysis_script}" > comprehensive_analysis.txt 2>&1 || echo "Analysis failed (Python not available)"

# Final summary
echo "=== COMPLETE VALIDATION SUITE FINISHED ==="
echo "Results directory: ${RUN_DIR}"
echo "Comprehensive analysis: ${RUN_DIR}/comprehensive_analysis.txt"
echo
echo "Experiment log files:"
ls -la "${RUN_DIR}"/*.log 2>/dev/null | wc -l | xargs echo "Log files:"
echo
echo "Total parameter combinations tested: $(echo "6*6*3*2 + 6*6*2*2 + 6*6*2*2 + 3*3*3 + 2*2*2 + 3*3*3" | bc 2>/dev/null || echo "~600")"
echo "Total individual evolution runs: $(echo "600 * $SEEDS" | bc 2>/dev/null || echo "~60,000")"
echo
echo "To examine results:"
echo "  cd ${RUN_DIR}"
echo "  cat comprehensive_analysis.txt"
echo "  # Individual log files contain experiment details"
echo
echo "Estimated runtime: ~$(echo "$SEEDS * 600 / $CORES / 3600" | bc -l 2>/dev/null | cut -d. -f1 || echo "8-12") hours"
echo "Started: ${TIMESTAMP}"
echo "Completed: $(date)"
