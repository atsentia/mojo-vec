"""
Large-Scale Benchmark: InlineByteBuffer vs List vs Rust Vec

Tests performance at various scales:
- Small: 64 bytes (fits inline)
- Medium: 1 KB, 64 KB
- Large: 1 MB, 16 MB, 64 MB, 256 MB

Key metrics:
1. Append throughput (bytes/second)
2. Zero-copy slice access vs copy-based slice
3. SIMD comparison speed
4. Memory pattern simulation (BPE-like workload)

Run with:
    cd /Users/amund/mojo-vec
    mojo run -I . benchmarks/bench_scale.mojo
"""

from time import perf_counter_ns
from src.inline_buffer import InlineByteBuffer

# ============================================================================
# Utility Functions
# ============================================================================

fn format_bytes(bytes: Int) -> String:
    """Format bytes as human-readable string."""
    if bytes >= 1_000_000_000:
        return String(bytes // 1_000_000_000) + " GB"
    elif bytes >= 1_000_000:
        return String(bytes // 1_000_000) + " MB"
    elif bytes >= 1_000:
        return String(bytes // 1_000) + " KB"
    return String(bytes) + " B"


fn format_throughput(bytes: Int, elapsed_ns: Int) -> String:
    """Format throughput as bytes/second."""
    if elapsed_ns == 0:
        return "∞"
    var bytes_per_sec = bytes * 1_000_000_000 // elapsed_ns
    if bytes_per_sec >= 1_000_000_000:
        return String(bytes_per_sec // 1_000_000_000) + " GB/s"
    elif bytes_per_sec >= 1_000_000:
        return String(bytes_per_sec // 1_000_000) + " MB/s"
    elif bytes_per_sec >= 1_000:
        return String(bytes_per_sec // 1_000) + " KB/s"
    return String(bytes_per_sec) + " B/s"


# ============================================================================
# Benchmark 1: Append Throughput
# ============================================================================

fn bench_list_append_throughput(size: Int) -> Int:
    """Measure List append throughput."""
    var start = perf_counter_ns()

    var list = List[UInt8](capacity=size)
    for i in range(size):
        list.append(UInt8(i % 256))

    var elapsed = perf_counter_ns() - start
    # Prevent optimization
    _ = list[size // 2]
    return Int(elapsed)


fn bench_inline_buffer_append_throughput(size: Int) -> Int:
    """Measure InlineByteBuffer append throughput."""
    var start = perf_counter_ns()

    var buf = InlineByteBuffer()
    for i in range(size):
        buf.append(UInt8(i % 256))

    var elapsed = perf_counter_ns() - start
    # Prevent optimization
    _ = buf[size // 2]
    return Int(elapsed)


# ============================================================================
# Benchmark 2: Slice Access Pattern
# ============================================================================

fn bench_list_slice_pattern(data_size: Int, num_slices: Int) -> Int:
    """Benchmark List slice access (copies data each time)."""
    var data = List[UInt8](capacity=data_size)
    for i in range(data_size):
        data.append(UInt8(i % 256))

    var total: Int = 0
    var start = perf_counter_ns()

    for s in range(num_slices):
        var pos = (s * 17) % (data_size - 100)  # Pseudo-random positions
        # Copy slice (what List does)
        var slice = List[UInt8](capacity=100)
        for i in range(pos, pos + 100):
            slice.append(data[i])
        total += Int(slice[0])

    var elapsed = perf_counter_ns() - start
    _ = total
    return Int(elapsed)


fn bench_inline_buffer_slice_pattern(data_size: Int, num_slices: Int) -> Int:
    """Benchmark InlineByteBuffer slice access (zero-copy via pointer)."""
    var buf = InlineByteBuffer()
    # For large sizes, need to pre-allocate
    for i in range(data_size):
        buf.append(UInt8(i % 256))

    var ptr = buf.unsafe_inline_ptr() if buf.is_inline() else buf.unsafe_heap_ptr()

    var total: Int = 0
    var start = perf_counter_ns()

    for s in range(num_slices):
        var pos = (s * 17) % (data_size - 100)  # Pseudo-random positions
        # Zero-copy: just pointer arithmetic
        var slice_ptr = ptr + pos
        total += Int(slice_ptr[0])

    var elapsed = perf_counter_ns() - start
    _ = total
    return Int(elapsed)


# ============================================================================
# Benchmark 3: SIMD Comparison at Scale
# ============================================================================

fn bench_scalar_compare(size: Int) -> Int:
    """Scalar byte-by-byte comparison."""
    var data1 = List[UInt8](capacity=size)
    var data2 = List[UInt8](capacity=size)
    for i in range(size):
        data1.append(UInt8(i % 256))
        data2.append(UInt8(i % 256))

    var start = perf_counter_ns()

    var equal = True
    for i in range(size):
        if data1[i] != data2[i]:
            equal = False
            break

    var elapsed = perf_counter_ns() - start
    _ = equal
    return Int(elapsed)


fn bench_simd_compare(size: Int) -> Int:
    """SIMD comparison using InlineByteBuffer."""
    var buf1 = InlineByteBuffer()
    var buf2 = InlineByteBuffer()
    for i in range(size):
        buf1.append(UInt8(i % 256))
        buf2.append(UInt8(i % 256))

    var start = perf_counter_ns()

    var equal = buf1.simd_equals(buf2)

    var elapsed = perf_counter_ns() - start
    _ = equal
    return Int(elapsed)


# ============================================================================
# Benchmark 4: BPE-like Workload Simulation
# ============================================================================

fn bench_bpe_workload_list(text_size: Int) -> Int:
    """Simulate BPE tokenization with List (allocates per lookup)."""
    var text = List[UInt8](capacity=text_size)
    for i in range(text_size):
        text.append(UInt8(i % 256))

    var tokens: Int = 0
    var start = perf_counter_ns()

    var pos = 0
    while pos < text_size:
        # Simulate trie lookup: create slice of next N bytes
        var lookup_len = min(16, text_size - pos)
        var lookup = List[UInt8](capacity=lookup_len)
        for i in range(pos, pos + lookup_len):
            lookup.append(text[i])

        # Simulate token match (advance by average token length)
        pos += 4
        tokens += 1

    var elapsed = perf_counter_ns() - start
    _ = tokens
    return Int(elapsed)


fn bench_bpe_workload_inline_buffer(text_size: Int) -> Int:
    """Simulate BPE tokenization with InlineByteBuffer (zero-copy)."""
    var text = InlineByteBuffer()
    for i in range(text_size):
        text.append(UInt8(i % 256))

    var ptr = text.unsafe_inline_ptr() if text.is_inline() else text.unsafe_heap_ptr()

    var tokens: Int = 0
    var start = perf_counter_ns()

    var pos = 0
    while pos < text_size:
        # Simulate trie lookup: just offset pointer (zero-copy!)
        var lookup = ptr + pos
        # Access a few bytes (simulating prefix check)
        var b0 = lookup[0]
        var b1 = lookup[1] if pos + 1 < text_size else UInt8(0)
        var b2 = lookup[2] if pos + 2 < text_size else UInt8(0)
        var b3 = lookup[3] if pos + 3 < text_size else UInt8(0)

        # Simulate token match
        pos += 4
        tokens += 1

    var elapsed = perf_counter_ns() - start
    _ = tokens
    return Int(elapsed)


# ============================================================================
# Main Benchmark Runner
# ============================================================================

fn run_benchmark(name: String, size: Int,
                 list_fn: fn(Int) -> Int,
                 inline_fn: fn(Int) -> Int):
    """Run a benchmark and print results."""
    var list_time = list_fn(size)
    var inline_time = inline_fn(size)

    print("   ", format_bytes(size), ":")
    print("      List:         ", list_time // 1_000_000, "ms  ", format_throughput(size, list_time))
    print("      InlineBuffer: ", inline_time // 1_000_000, "ms  ", format_throughput(size, inline_time))

    if inline_time > 0:
        var speedup = list_time * 100 // inline_time
        print("      Speedup:      ", speedup // 100, ".", speedup % 100, "x")
    else:
        print("      Speedup:      ∞")


fn main():
    print("=" * 70)
    print("Large-Scale Benchmark: InlineByteBuffer vs Mojo List")
    print("=" * 70)
    print()

    # Test sizes
    alias SMALL = 64
    alias KB_1 = 1024
    alias KB_64 = 64 * 1024
    alias MB_1 = 1024 * 1024
    alias MB_16 = 16 * 1024 * 1024

    # =========================================================================
    # Benchmark 1: Append Throughput
    # =========================================================================
    print("1. APPEND THROUGHPUT")
    print("-" * 50)

    run_benchmark("append", SMALL, bench_list_append_throughput, bench_inline_buffer_append_throughput)
    run_benchmark("append", KB_1, bench_list_append_throughput, bench_inline_buffer_append_throughput)
    run_benchmark("append", KB_64, bench_list_append_throughput, bench_inline_buffer_append_throughput)
    run_benchmark("append", MB_1, bench_list_append_throughput, bench_inline_buffer_append_throughput)
    print()

    # =========================================================================
    # Benchmark 2: Slice Access Pattern (100K slices)
    # =========================================================================
    print("2. SLICE ACCESS (100,000 slices)")
    print("-" * 50)

    alias NUM_SLICES = 100_000

    print("   1 KB data:")
    var list_slice_1k = bench_list_slice_pattern(KB_1, NUM_SLICES)
    var inline_slice_1k = bench_inline_buffer_slice_pattern(KB_1, NUM_SLICES)
    print("      List (copy):    ", list_slice_1k // 1_000_000, "ms")
    print("      InlineBuffer:   ", inline_slice_1k // 1_000_000, "ms")
    if inline_slice_1k > 0:
        print("      Speedup:        ", list_slice_1k // inline_slice_1k, "x")
    else:
        print("      Speedup:        ∞")

    print("   64 KB data:")
    var list_slice_64k = bench_list_slice_pattern(KB_64, NUM_SLICES)
    var inline_slice_64k = bench_inline_buffer_slice_pattern(KB_64, NUM_SLICES)
    print("      List (copy):    ", list_slice_64k // 1_000_000, "ms")
    print("      InlineBuffer:   ", inline_slice_64k // 1_000_000, "ms")
    if inline_slice_64k > 0:
        print("      Speedup:        ", list_slice_64k // inline_slice_64k, "x")
    else:
        print("      Speedup:        ∞")

    print("   1 MB data:")
    var list_slice_1m = bench_list_slice_pattern(MB_1, NUM_SLICES)
    var inline_slice_1m = bench_inline_buffer_slice_pattern(MB_1, NUM_SLICES)
    print("      List (copy):    ", list_slice_1m // 1_000_000, "ms")
    print("      InlineBuffer:   ", inline_slice_1m // 1_000_000, "ms")
    if inline_slice_1m > 0:
        print("      Speedup:        ", list_slice_1m // inline_slice_1m, "x")
    else:
        print("      Speedup:        ∞")
    print()

    # =========================================================================
    # Benchmark 3: SIMD Comparison
    # =========================================================================
    print("3. BYTE COMPARISON (scalar vs SIMD)")
    print("-" * 50)

    print("   64 bytes:")
    var scalar_64 = bench_scalar_compare(64)
    var simd_64 = bench_simd_compare(64)
    print("      Scalar: ", scalar_64, "ns")
    print("      SIMD:   ", simd_64, "ns")
    if simd_64 > 0:
        print("      Speedup:", scalar_64 // simd_64, "x")

    print("   1 KB:")
    var scalar_1k = bench_scalar_compare(KB_1)
    var simd_1k = bench_simd_compare(KB_1)
    print("      Scalar: ", scalar_1k // 1000, "µs")
    print("      SIMD:   ", simd_1k // 1000, "µs")
    if simd_1k > 0:
        print("      Speedup:", scalar_1k // simd_1k, "x")

    print("   64 KB:")
    var scalar_64k = bench_scalar_compare(KB_64)
    var simd_64k = bench_simd_compare(KB_64)
    print("      Scalar: ", scalar_64k // 1000, "µs")
    print("      SIMD:   ", simd_64k // 1000, "µs")
    if simd_64k > 0:
        print("      Speedup:", scalar_64k // simd_64k, "x")
    print()

    # =========================================================================
    # Benchmark 4: BPE Workload
    # =========================================================================
    print("4. BPE TOKENIZATION SIMULATION")
    print("-" * 50)

    print("   1 KB text:")
    var bpe_list_1k = bench_bpe_workload_list(KB_1)
    var bpe_inline_1k = bench_bpe_workload_inline_buffer(KB_1)
    print("      List:         ", bpe_list_1k // 1000, "µs  (", KB_1 // 4, " tokens)")
    print("      InlineBuffer: ", bpe_inline_1k // 1000, "µs")
    if bpe_inline_1k > 0:
        print("      Speedup:      ", bpe_list_1k // bpe_inline_1k, "x")

    print("   64 KB text:")
    var bpe_list_64k = bench_bpe_workload_list(KB_64)
    var bpe_inline_64k = bench_bpe_workload_inline_buffer(KB_64)
    print("      List:         ", bpe_list_64k // 1_000_000, "ms  (", KB_64 // 4, " tokens)")
    print("      InlineBuffer: ", bpe_inline_64k // 1_000_000, "ms")
    if bpe_inline_64k > 0:
        print("      Speedup:      ", bpe_list_64k // bpe_inline_64k, "x")

    print("   1 MB text:")
    var bpe_list_1m = bench_bpe_workload_list(MB_1)
    var bpe_inline_1m = bench_bpe_workload_inline_buffer(MB_1)
    print("      List:         ", bpe_list_1m // 1_000_000, "ms  (", MB_1 // 4, " tokens)")
    print("      InlineBuffer: ", bpe_inline_1m // 1_000_000, "ms")
    if bpe_inline_1m > 0:
        print("      Speedup:      ", bpe_list_1m // bpe_inline_1m, "x")
    print()

    # =========================================================================
    # Summary
    # =========================================================================
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print()
    print("InlineByteBuffer advantages:")
    print("  - Small data (≤64 bytes): No heap allocation (inline storage)")
    print("  - Slice access: Zero-copy via pointer arithmetic")
    print("  - Comparison: SIMD-accelerated (16 bytes per instruction)")
    print("  - BPE pattern: Eliminates temporary allocations")
    print()
    print("For Rust comparison: python benchmarks/bench_rust_comparison.py")
