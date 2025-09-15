#!/bin/bash

echo "Running AI Ground-Up Computing Experiments"
echo "=========================================="
echo

# Build once with optimizations
cargo build --release

# Run baseline binary test
echo "1. BASELINE - Binary Discovery"
cargo run --release -- binary > results_binary.txt 2>&1
tail -n 10 results_binary.txt
echo

# Run ternary preference test
echo "2. TERNARY - Testing 3-state preference"
cargo run --release -- ternary > results_ternary.txt 2>&1
tail -n 10 results_ternary.txt
echo

# Run high noise test
echo "3. HIGH NOISE - Testing 3x noise"
cargo run --release -- high_noise > results_high_noise.txt 2>&1
tail -n 10 results_high_noise.txt
echo

# Run extreme noise test
echo "4. EXTREME NOISE - Testing 5x noise"
cargo run --release -- extreme_noise > results_extreme_noise.txt 2>&1
tail -n 10 results_extreme_noise.txt
echo

echo "All experiments complete! Check results_*.txt for full outputs"
