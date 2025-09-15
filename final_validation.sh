#!/bin/bash

# FINAL COMPLETE VALIDATION SUITE
# Implements ChatGPT's full roadmap including optimizer and fitness ablations

set -e  

BINARY="./target/release/ai-ground-up"
RESULTS_DIR="validation_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${RESULTS_DIR}/${TIMESTAMP}_COMPLETE"

SEEDS=100
CORES=$(nproc)

echo "=== FINAL COMPLETE VALIDATION SUITE ==="
echo "All optimizer variants, fitness functions, and statistical rigor"
echo "Timestamp: ${TIMESTAMP}"
echo "Results directory: ${RUN_DIR}"
echo "Using ${CORES} CPU cores, ${SEEDS} seeds per condition"
echo

mkdir -p "${RUN_DIR}"
cd "$(dirname "$0")"

echo "Building release binary..."
cargo build --release

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Binary not found at ${BINARY}"
    exit 1
fi

run_test() {
    local name="$1"
    local cmd="$2"
    local output_file="${RUN_DIR}/${name}.log"
    
    echo "=== Running: ${name} ==="
    echo "Command: ${cmd}"
    echo "Started: $(date)"
    
    echo "# Command: ${cmd}" > "${output_file}"
    echo "# Started: $(date)" >> "${output_file}"
    echo "# Git commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')" >> "${output_file}"
    echo "# Seeds: ${SEEDS}" >> "${output_file}"
    echo >> "${output_file}"
    
    eval "${cmd}" >> "${output_file}" 2>&1
    
    echo "Completed: $(date)"
    echo
}

# PHASE A: Core continuous-only tests (all optimizers)
echo "=== PHASE A: Continuous-only with all optimizers (H1/H4) ==="

for optimizer in ga random cmaes; do
    for energy_model in base leak; do
        name="cont_${optimizer}_${energy_model}"
        cmd="${BINARY} sweep-extended \
            --sweep-allowed=continuous_only \
            --sweep-sigmas=0.1,0.3,0.5 \
            --sweep-energy-zero=0.2,2.0,10.0 \
            --sweep-energy-abs1=1.0 \
            --sweep-gens=120 --sweep-pop=40 --sweep-seeds=${SEEDS} \
            --energy-model=${energy_model} \
            --sweep-optimizer=${optimizer} \
            --sweep-fitness=task \
            --sweep-stdout=summary"
        
        run_test "${name}" "${cmd}"
    done
done

# PHASE B: Fitness function ablations (H5)
echo "=== PHASE B: Fitness function ablations (H5) ==="

for fitness in task reg info; do
    for energy_model in base asym leak; do
        name="fitness_${fitness}_${energy_model}"
        cmd="${BINARY} sweep-extended \
            --sweep-allowed=continuous_only \
            --sweep-sigmas=0.1,0.3,0.5 \
            --sweep-energy-zero=0.2,2.0,10.0 \
            --sweep-energy-abs1=1.0 \
            --sweep-gens=120 --sweep-pop=40 --sweep-seeds=${SEEDS} \
            --energy-model=${energy_model} \
            --sweep-optimizer=ga \
            --sweep-fitness=${fitness} \
            --sweep-stdout=summary"
        
        run_test "${name}" "${cmd}"
    done
done

# PHASE C: Binary-only constraint validation (H3)
echo "=== PHASE C: Binary-only validation across optimizers (H3) ==="

for optimizer in ga random cmaes; do
    name="binary_${optimizer}"
    cmd="${BINARY} sweep-extended \
        --sweep-allowed=binary_only \
        --sweep-sigmas=0.1,0.3,0.5 \
        --sweep-energy-zero=0.2,2.0,10.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=120 --sweep-pop=40 --sweep-seeds=${SEEDS} \
        --energy-model=base \
        --sweep-optimizer=${optimizer} \
        --sweep-fitness=task \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# PHASE D: Discrete-only baseline across optimizers
echo "=== PHASE D: Discrete-only validation across optimizers ==="

for optimizer in ga random cmaes; do
    name="discrete_${optimizer}"
    cmd="${BINARY} sweep-extended \
        --sweep-allowed=discrete_only \
        --sweep-sigmas=0.1,0.3,0.5 \
        --sweep-energy-zero=0.2,2.0,10.0 \
        --sweep-energy-abs1=1.0 \
        --sweep-gens=120 --sweep-pop=40 --sweep-seeds=${SEEDS} \
        --energy-model=base \
        --sweep-optimizer=${optimizer} \
        --sweep-fitness=task \
        --sweep-stdout=summary"
    
    run_test "${name}" "${cmd}"
done

# PHASE E: Deep convergence tests
echo "=== PHASE E: Deep convergence analysis ==="

# Extended generations
name="convergence_1000gen"
cmd="${BINARY} sweep \
    --sweep-allowed=continuous_only \
    --sweep-sigmas=0.1,0.3 \
    --sweep-energy-zero=0.2,10.0 \
    --sweep-energy-abs1=1.0 \
    --sweep-gens=1000 --sweep-pop=40 --sweep-seeds=${SEEDS} \
    --energy-model=base \
    --sweep-optimizer=ga \
    --sweep-fitness=task \
    --sweep-stdout=summary"

run_test "${name}" "${cmd}"

# Large population
name="convergence_pop200"
cmd="${BINARY} sweep \
    --sweep-allowed=continuous_only \
    --sweep-sigmas=0.1,0.3 \
    --sweep-energy-zero=0.2,2.0 \
    --sweep-energy-abs1=1.0 \
    --sweep-gens=120 --sweep-pop=200 --sweep-seeds=${SEEDS} \
    --energy-model=base \
    --sweep-optimizer=ga \
    --sweep-fitness=task \
    --sweep-stdout=summary"

run_test "${name}" "${cmd}"

# FINAL ANALYSIS
echo "=== Generating final comprehensive analysis ==="
analysis_script="${RUN_DIR}/final_analysis.py"

cat > "${analysis_script}" << 'EOF'
#!/usr/bin/env python3
import re
import glob
import os
import json
from pathlib import Path
from collections import defaultdict, Counter
import math

def parse_csv_rows_from_log(log_content):
    """Extract CSV_ROW lines and metadata from log output"""
    rows = []
    metadata = {}
    
    for line in log_content.split('\n'):
        if line.startswith('# '):
            if 'Seeds:' in line:
                metadata['seeds'] = int(line.split()[-1])
            elif 'Command:' in line:
                # Extract optimizer and fitness from command
                cmd = line[2:].strip()
                if '--sweep-optimizer=' in cmd:
                    opt_match = re.search(r'--sweep-optimizer=(\w+)', cmd)
                    metadata['optimizer'] = opt_match.group(1) if opt_match else 'ga'
                if '--sweep-fitness=' in cmd:
                    fit_match = re.search(r'--sweep-fitness=(\w+)', cmd)
                    metadata['fitness'] = fit_match.group(1) if fit_match else 'task'
                metadata['command'] = cmd
        elif 'optimizer=' in line and 'fitness=' in line:
            # Parse experiment parameters
            parts = line.split()
            for part in parts:
                if '=' in part:
                    key, value = part.split('=', 1)
                    if key in ['optimizer', 'fitness', 'energy_model']:
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
    """Calculate Wilson score interval for binomial proportion"""
    if trials == 0:
        return (0, 0)
    
    p = successes / trials
    z = 1.96  # 95% confidence
    
    # Wilson score interval (more accurate for small samples)
    denominator = 1 + z**2 / trials
    centre = (p + z**2 / (2 * trials)) / denominator
    margin = z * math.sqrt((p * (1 - p) + z**2 / (4 * trials)) / trials) / denominator
    
    return (max(0, centre - margin), min(1, centre + margin))

def analyze_final_results():
    """Final comprehensive analysis with full statistical rigor"""
    log_files = glob.glob('*.log')
    
    if not log_files:
        print("No log files found")
        return
    
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
            row['optimizer'] = metadata.get('optimizer', 'ga')
            row['fitness'] = metadata.get('fitness', 'task')
            row['energy_model'] = metadata.get('energy_model', 'base')
            all_data.append(row)
    
    if not all_data:
        print("No valid data found")
        return
    
    print("=== FINAL COMPREHENSIVE VALIDATION RESULTS ===")
    print(f"Total experiments: {len(log_files)}")
    print(f"Total parameter combinations: {len(all_data)}")
    print(f"Average seeds per combination: {sum(r['consensus'][1] for r in all_data if r['consensus']) / len([r for r in all_data if r['consensus']]):.1f}")
    print()
    
    # Overall state distribution with confidence intervals
    print("=== OVERALL STATE DISTRIBUTION (with 95% CIs) ===")
    state_counts = Counter(row['n_states'] for row in all_data)
    total = len(all_data)
    
    for states in sorted(state_counts.keys()):
        count = state_counts[states]
        rate = count / total
        ci = calculate_confidence_interval(count, total)
        state_name = {0: 'Analog', 1: 'Single', 2: 'Binary', 3: 'Ternary', 4: 'Quaternary'}.get(states, f'{states}-state')
        print(f"{state_name:10}: {count:4d}/{total} ({rate:.3f}) [95% CI: {ci[0]:.3f}-{ci[1]:.3f}]")
    
    print()
    
    # H1: Continuous-only analysis across all optimizers
    print("=== H1: CONTINUOUS-ONLY ANALYSIS BY OPTIMIZER ===")
    
    cont_data = [r for r in all_data if 'cont_' in r['experiment'] and r['sigma'] <= 0.3]
    
    for optimizer in ['ga', 'random', 'cmaes']:
        opt_data = [r for r in cont_data if r['optimizer'] == optimizer]
        if opt_data:
            ternary_count = sum(1 for r in opt_data if r['n_states'] == 3)
            binary_count = sum(1 for r in opt_data if r['n_states'] == 2)
            total_opt = len(opt_data)
            
            ternary_rate = ternary_count / total_opt
            binary_rate = binary_count / total_opt
            
            ternary_ci = calculate_confidence_interval(ternary_count, total_opt)
            binary_ci = calculate_confidence_interval(binary_count, total_opt)
            
            print(f"{optimizer.upper():8}: T={ternary_count:2d}/{total_opt} ({ternary_rate:.3f}) [{ternary_ci[0]:.3f}-{ternary_ci[1]:.3f}] | B={binary_count:2d}/{total_opt} ({binary_rate:.3f}) [{binary_ci[0]:.3f}-{binary_ci[1]:.3f}]")
    
    print(f"H1 Result: {'CONSISTENT ACROSS OPTIMIZERS' if all(sum(1 for r in cont_data if r['optimizer'] == opt and r['n_states'] == 3) == 0 for opt in ['ga', 'random', 'cmaes']) else 'OPTIMIZER-DEPENDENT'}")
    print()
    
    # H3: Binary-only constraint validation
    print("=== H3: BINARY-ONLY CONSTRAINT VALIDATION ===")
    
    binary_data = [r for r in all_data if 'binary_' in r['experiment']]
    if binary_data:
        for optimizer in ['ga', 'random', 'cmaes']:
            opt_data = [r for r in binary_data if r['optimizer'] == optimizer]
            if opt_data:
                binary_count = sum(1 for r in opt_data if r['n_states'] == 2)
                total_opt = len(opt_data)
                binary_rate = binary_count / total_opt
                ci = calculate_confidence_interval(binary_count, total_opt)
                
                result = "PASS" if ci[0] >= 0.90 else "FAIL"
                print(f"{optimizer.upper():8}: {binary_count:2d}/{total_opt} ({binary_rate:.3f}) [95% CI: {ci[0]:.3f}-{ci[1]:.3f}] - {result}")
    
    print()
    
    # H5: Fitness function analysis
    print("=== H5: FITNESS FUNCTION ROBUSTNESS ===")
    
    fitness_data = [r for r in all_data if 'fitness_' in r['experiment']]
    if fitness_data:
        for fitness in ['task', 'reg', 'info']:
            fit_data = [r for r in fitness_data if r['fitness'] == fitness]
            if fit_data:
                ternary_count = sum(1 for r in fit_data if r['n_states'] == 3)
                binary_count = sum(1 for r in fit_data if r['n_states'] == 2)
                total_fit = len(fit_data)
                
                ternary_rate = ternary_count / total_fit
                ternary_ci = calculate_confidence_interval(ternary_count, total_fit)
                
                print(f"{fitness.upper():8}: T={ternary_count:2d}/{total_fit} ({ternary_rate:.3f}) [95% CI: {ternary_ci[0]:.3f}-{ternary_ci[1]:.3f}]")
    
    print()
    
    # Energy model robustness summary
    print("=== ENERGY MODEL ROBUSTNESS SUMMARY ===")
    for energy_model in ['base', 'asym', 'leak']:
        model_data = [r for r in all_data if 'cont_' in r['experiment'] and r.get('energy_model') == energy_model]
        if model_data:
            ternary_count = sum(1 for r in model_data if r['n_states'] == 3)
            total_model = len(model_data)
            ternary_rate = ternary_count / total_model
            ci = calculate_confidence_interval(ternary_count, total_model)
            
            print(f"{energy_model.upper():8}: T={ternary_count:2d}/{total_model} ({ternary_rate:.3f}) [95% CI: {ci[0]:.3f}-{ci[1]:.3f}]")
    
    print()
    
    # Final summary statistics
    print("=== FINAL SUMMARY AND CONCLUSIONS ===")
    
    # Count experiments by type
    cont_experiments = len([e for e in experiments if 'cont_' in e])
    binary_experiments = len([e for e in experiments if 'binary_' in e])
    discrete_experiments = len([e for e in experiments if 'discrete_' in e])
    
    print(f"Experiments completed:")
    print(f"  Continuous-only: {cont_experiments}")
    print(f"  Binary-only:     {binary_experiments}")
    print(f"  Discrete-only:   {discrete_experiments}")
    print(f"  Total:           {len(experiments)}")
    print()
    
    # Overall conclusions
    cont_ternary_rate = sum(1 for r in all_data if 'cont_' in r['experiment'] and r['n_states'] == 3) / len([r for r in all_data if 'cont_' in r['experiment']])
    discrete_ternary_rate = sum(1 for r in all_data if 'discrete_' in r['experiment'] and r['n_states'] == 3) / len([r for r in all_data if 'discrete_' in r['experiment']])
    binary_constraint_rate = sum(1 for r in all_data if 'binary_' in r['experiment'] and r['n_states'] == 2) / len([r for r in all_data if 'binary_' in r['experiment']])
    
    print("CONCLUSIONS:")
    print(f"1. Continuous-only ternary rate: {cont_ternary_rate:.3f} - {'TERNARY EMERGENCE CONFIRMED' if cont_ternary_rate > 0.1 else 'NO SIGNIFICANT TERNARY EMERGENCE'}")
    print(f"2. Discrete-only ternary rate:   {discrete_ternary_rate:.3f} - {'TERNARY WITH QUANTIZERS' if discrete_ternary_rate > 0.5 else 'LIMITED TERNARY'}")
    print(f"3. Binary constraint success:    {binary_constraint_rate:.3f} - {'CONSTRAINTS WORK' if binary_constraint_rate > 0.9 else 'CONSTRAINT VIOLATION'}")
    print()
    
    optimizer_consistency = True
    for optimizer in ['ga', 'random', 'cmaes']:
        opt_ternary = sum(1 for r in all_data if 'cont_' in r['experiment'] and r.get('optimizer') == optimizer and r['n_states'] == 3)
        if opt_ternary > 0:
            optimizer_consistency = False
            break
    
    print(f"4. Optimizer consistency: {'CONFIRMED - no optimizer produces ternary in continuous systems' if optimizer_consistency else 'OPTIMIZER-DEPENDENT - ternary emergence varies by algorithm'}")
    
    # Save detailed results
    summary_data = {
        'total_experiments': len(log_files),
        'total_combinations': len(all_data),
        'state_distribution': dict(Counter(row['n_states'] for row in all_data)),
        'continuous_ternary_rate': cont_ternary_rate,
        'discrete_ternary_rate': discrete_ternary_rate,
        'binary_constraint_rate': binary_constraint_rate,
        'optimizer_consistency': optimizer_consistency,
        'experiments': {name: {'conditions': len(exp['data']), 'metadata': exp['metadata']} 
                      for name, exp in experiments.items()}
    }
    
    with open('final_validation_summary.json', 'w') as f:
        json.dump(summary_data, f, indent=2)
    
    print(f"\nDetailed summary saved to: final_validation_summary.json")
    print(f"Individual experiment logs: {len(log_files)} files")

if __name__ == '__main__':
    analyze_final_results()
EOF

chmod +x "${analysis_script}"

echo "Running final comprehensive analysis..."
cd "${RUN_DIR}"
python3 "${analysis_script}" > final_analysis.txt 2>&1 || echo "Analysis failed (Python not available)"

echo "=== FINAL VALIDATION SUITE COMPLETE ==="
echo "Results directory: ${RUN_DIR}"
echo "Final analysis: ${RUN_DIR}/final_analysis.txt"
echo
echo "Comprehensive experiments completed:"
echo "- Optimizer ablations: GA vs Random Search vs CMA-ES"
echo "- Fitness function variants: Task vs Regularized vs Information-theoretic" 
echo "- Energy model robustness: Base vs Asymmetric vs Leak"
echo "- Statistical rigor: 100 seeds per condition with 95% confidence intervals"
echo
echo "Total experiments: $(ls ${RUN_DIR}/*.log 2>/dev/null | wc -l || echo 0)"
echo "Estimated total evolution runs: ~15,000-20,000"
echo
echo "To examine results:"
echo "  cd ${RUN_DIR}"
echo "  cat final_analysis.txt"
echo "  cat final_validation_summary.json"
echo
echo "Started: ${TIMESTAMP}"
echo "Completed: $(date)"
