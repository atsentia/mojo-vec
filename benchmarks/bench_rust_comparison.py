#!/usr/bin/env python3
"""
Benchmark: Rust Vec comparison

This script compiles and runs equivalent Rust benchmarks for comparison
with Mojo List and SmallByteVec.

Requirements:
    - rustc installed
    - Runs on macOS/Linux

Usage:
    python benchmarks/bench_rust_comparison.py
"""

import subprocess
import tempfile
import os
import time

RUST_BENCHMARK_CODE = '''
use std::time::Instant;

const ITERATIONS: usize = 10_000;
const SMALL_SIZE: usize = 32;
const LARGE_SIZE: usize = 128;
const DATA_SIZE: usize = 1000;
const CMP_SIZE: usize = 64;
const TEXT_SIZE: usize = 1000;

fn format_rate(elapsed_ns: u128, operations: usize) -> String {
    let ops_per_sec = (operations as u128) * 1_000_000_000 / elapsed_ns;
    if ops_per_sec >= 1_000_000 {
        format!("{} M/s", ops_per_sec / 1_000_000)
    } else if ops_per_sec >= 1_000 {
        format!("{} K/s", ops_per_sec / 1_000)
    } else {
        format!("{} /s", ops_per_sec)
    }
}

// Benchmark 1: Append Operations
fn bench_vec_append(iterations: usize, size: usize) -> u128 {
    let start = Instant::now();
    let mut total = 0usize;

    for _ in 0..iterations {
        let mut vec: Vec<u8> = Vec::with_capacity(size);
        for i in 0..size {
            vec.push((i % 256) as u8);
        }
        total += vec.len();
    }

    // Prevent optimization
    std::hint::black_box(total);
    start.elapsed().as_nanos()
}

// Benchmark 2: Slice Operations
fn bench_vec_slice_copy(iterations: usize, data_size: usize) -> u128 {
    // Pre-create data
    let data: Vec<u8> = (0..data_size).map(|i| (i % 256) as u8).collect();

    let start = Instant::now();
    let mut total = 0u8;

    for _ in 0..iterations {
        let pos = data_size / 2;
        // Copy slice (equivalent to Mojo List behavior)
        let remaining: Vec<u8> = data[pos..].to_vec();
        total = total.wrapping_add(remaining[0]);
    }

    std::hint::black_box(total);
    start.elapsed().as_nanos()
}

fn bench_vec_slice_zerocopy(iterations: usize, data_size: usize) -> u128 {
    // Pre-create data
    let data: Vec<u8> = (0..data_size).map(|i| (i % 256) as u8).collect();

    let start = Instant::now();
    let mut total = 0u8;

    for _ in 0..iterations {
        let pos = data_size / 2;
        // Zero-copy slice (Rust &[u8])
        let remaining = &data[pos..];
        total = total.wrapping_add(remaining[0]);
    }

    std::hint::black_box(total);
    start.elapsed().as_nanos()
}

// Benchmark 3: Comparison Operations
fn bench_vec_compare_scalar(iterations: usize, size: usize) -> u128 {
    let data1: Vec<u8> = (0..size).map(|i| (i % 256) as u8).collect();
    let data2: Vec<u8> = (0..size).map(|i| (i % 256) as u8).collect();

    let start = Instant::now();
    let mut matches = 0usize;

    for _ in 0..iterations {
        let mut equal = true;
        for i in 0..size {
            if data1[i] != data2[i] {
                equal = false;
                break;
            }
        }
        if equal {
            matches += 1;
        }
    }

    std::hint::black_box(matches);
    start.elapsed().as_nanos()
}

fn bench_vec_compare_slice_eq(iterations: usize, size: usize) -> u128 {
    let data1: Vec<u8> = (0..size).map(|i| (i % 256) as u8).collect();
    let data2: Vec<u8> = (0..size).map(|i| (i % 256) as u8).collect();

    let start = Instant::now();
    let mut matches = 0usize;

    for _ in 0..iterations {
        // Rust's optimized slice comparison (uses SIMD internally)
        if data1 == data2 {
            matches += 1;
        }
    }

    std::hint::black_box(matches);
    start.elapsed().as_nanos()
}

// Benchmark 4: BPE Pattern
fn bench_vec_bpe_copy(iterations: usize, text_size: usize) -> u128 {
    let text: Vec<u8> = (0..text_size).map(|i| (i % 256) as u8).collect();

    let start = Instant::now();
    let mut tokens = 0usize;

    for _ in 0..iterations {
        let mut pos = 0;
        while pos < text_size {
            // Copy slice (equivalent to Mojo List behavior)
            let end = std::cmp::min(pos + 10, text_size);
            let _remaining: Vec<u8> = text[pos..end].to_vec();
            pos += 3;
            tokens += 1;
        }
    }

    std::hint::black_box(tokens);
    start.elapsed().as_nanos()
}

fn bench_vec_bpe_zerocopy(iterations: usize, text_size: usize) -> u128 {
    let text: Vec<u8> = (0..text_size).map(|i| (i % 256) as u8).collect();

    let start = Instant::now();
    let mut tokens = 0usize;

    for _ in 0..iterations {
        let mut pos = 0;
        while pos < text_size {
            // Zero-copy slice (Rust &[u8])
            let remaining = &text[pos..];
            let _b0 = remaining[0];
            let _b1 = if pos + 1 < text_size { remaining[1] } else { 0 };
            let _b2 = if pos + 2 < text_size { remaining[2] } else { 0 };
            pos += 3;
            tokens += 1;
        }
    }

    std::hint::black_box(tokens);
    start.elapsed().as_nanos()
}

fn main() {
    println!("{}", "=".repeat(70));
    println!("Benchmark: Rust Vec<u8>");
    println!("{}", "=".repeat(70));
    println!();

    // Benchmark 1: Append
    println!("1. APPEND OPERATIONS ({} iterations)", ITERATIONS);
    println!("{}", "-".repeat(50));

    let vec_append_small = bench_vec_append(ITERATIONS, SMALL_SIZE);
    println!("   Size = {} (small)", SMALL_SIZE);
    println!("   Vec<u8>:     {} ms  {}", vec_append_small / 1_000_000, format_rate(vec_append_small, ITERATIONS));

    let vec_append_large = bench_vec_append(ITERATIONS, LARGE_SIZE);
    println!("   Size = {} (large)", LARGE_SIZE);
    println!("   Vec<u8>:     {} ms  {}", vec_append_large / 1_000_000, format_rate(vec_append_large, ITERATIONS));
    println!();

    // Benchmark 2: Slice
    println!("2. SLICE OPERATIONS ({} iterations)", ITERATIONS * 10);
    println!("{}", "-".repeat(50));

    let vec_slice_copy = bench_vec_slice_copy(ITERATIONS * 10, DATA_SIZE);
    let vec_slice_zerocopy = bench_vec_slice_zerocopy(ITERATIONS * 10, DATA_SIZE);

    println!("   Vec (copy):       {} ms  {}", vec_slice_copy / 1_000_000, format_rate(vec_slice_copy, ITERATIONS * 10));
    println!("   Vec (zero-copy):  {} ms  {}", vec_slice_zerocopy / 1_000_000, format_rate(vec_slice_zerocopy, ITERATIONS * 10));
    if vec_slice_zerocopy > 0 {
        println!("   Speedup:          {}x", vec_slice_copy / vec_slice_zerocopy);
    }
    println!();

    // Benchmark 3: Comparison
    println!("3. BYTE COMPARISON ({} iterations)", ITERATIONS);
    println!("{}", "-".repeat(50));

    let vec_cmp_scalar = bench_vec_compare_scalar(ITERATIONS, CMP_SIZE);
    let vec_cmp_slice = bench_vec_compare_slice_eq(ITERATIONS, CMP_SIZE);

    println!("   Vec (scalar):     {} ms  {}", vec_cmp_scalar / 1_000_000, format_rate(vec_cmp_scalar, ITERATIONS));
    println!("   Vec (slice eq):   {} ms  {}", vec_cmp_slice / 1_000_000, format_rate(vec_cmp_slice, ITERATIONS));
    if vec_cmp_slice > 0 {
        println!("   Speedup:          {}x", vec_cmp_scalar / vec_cmp_slice);
    }
    println!();

    // Benchmark 4: BPE Pattern
    println!("4. BPE ENCODING PATTERN ({} iterations)", ITERATIONS / 10);
    println!("{}", "-".repeat(50));

    let vec_bpe_copy = bench_vec_bpe_copy(ITERATIONS / 10, TEXT_SIZE);
    let vec_bpe_zerocopy = bench_vec_bpe_zerocopy(ITERATIONS / 10, TEXT_SIZE);

    println!("   Vec (copy):       {} ms  {}", vec_bpe_copy / 1_000_000, format_rate(vec_bpe_copy, ITERATIONS / 10));
    println!("   Vec (zero-copy):  {} ms  {}", vec_bpe_zerocopy / 1_000_000, format_rate(vec_bpe_zerocopy, ITERATIONS / 10));
    if vec_bpe_zerocopy > 0 {
        println!("   Speedup:          {}x", vec_bpe_copy / vec_bpe_zerocopy);
    }
    println!();

    println!("{}", "=".repeat(70));
    println!("KEY INSIGHT: Rust's &[T] slice is zero-copy by default.");
    println!("Mojo's mojo-vec achieves the same via unsafe_ptr() + pointer arithmetic.");
    println!("{}", "=".repeat(70));
}
'''

def main():
    print("=" * 70)
    print("Compiling and running Rust Vec benchmark...")
    print("=" * 70)
    print()

    # Create temporary directory for Rust code
    with tempfile.TemporaryDirectory() as tmpdir:
        rust_file = os.path.join(tmpdir, "bench.rs")
        binary_file = os.path.join(tmpdir, "bench")

        # Write Rust code
        with open(rust_file, 'w') as f:
            f.write(RUST_BENCHMARK_CODE)

        # Compile with optimizations
        print("Compiling with: rustc -O -o bench bench.rs")
        result = subprocess.run(
            ["rustc", "-O", "-o", binary_file, rust_file],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print("Compilation failed:")
            print(result.stderr)
            return 1

        print("Compilation successful!")
        print()

        # Run benchmark
        result = subprocess.run([binary_file], capture_output=True, text=True)
        print(result.stdout)

        if result.stderr:
            print("Errors:", result.stderr)

    return 0

if __name__ == "__main__":
    exit(main())
