"""
Benchmark: Mojo List vs mojo-vec SmallVec vs Rust Vec

This benchmark simulates real-world BPE tokenization patterns:
1. Append operations (building token sequences)
2. Slice operations (looking up remaining bytes in trie)
3. SIMD comparison (prefix matching)
4. Mixed operations (realistic tokenization loop)

Run with:
    mojo run -I .. benchmarks/bench_comparison.mojo
"""

from time import perf_counter_ns
from src.inline_buffer import InlineByteBuffer

# ============================================================================
# Benchmark 1: Append Operations
# ============================================================================

fn bench_list_append(iterations: Int, size: Int) -> Int:
    """Benchmark List[UInt8] append operations."""
    var total: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        var list = List[UInt8](capacity=size)
        for i in range(size):
            list.append(UInt8(i % 256))
        total += len(list)

    var elapsed = perf_counter_ns() - start
    return elapsed


fn bench_smallvec_append(iterations: Int, size: Int) -> Int:
    """Benchmark InlineByteBuffer append operations."""
    var total: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        var vec = InlineByteBuffer()
        for i in range(size):
            vec.append(UInt8(i % 256))
        total += len(vec)

    var elapsed = perf_counter_ns() - start
    return elapsed


# ============================================================================
# Benchmark 2: Slice Operations (Critical for BPE)
# ============================================================================

fn bench_list_slice(iterations: Int, data_size: Int) -> Int:
    """Benchmark List slice via copy (current approach)."""
    # Pre-create data
    var data = List[UInt8](capacity=data_size)
    for i in range(data_size):
        data.append(UInt8(i % 256))

    var total: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        # Simulate BPE: for each position, create remaining slice
        var pos = data_size // 2
        var remaining = List[UInt8](capacity=data_size - pos)
        for i in range(pos, data_size):
            remaining.append(data[i])
        total += Int(remaining[0])

    var elapsed = perf_counter_ns() - start
    return elapsed


fn bench_smallvec_slice_zerocopy(iterations: Int, data_size: Int) -> Int:
    """Benchmark InlineByteBuffer zero-copy slice via pointer."""
    # Pre-create data
    var data = InlineByteBuffer()
    for i in range(data_size):
        data.append(UInt8(i % 256))

    var total: Int = 0
    var start = perf_counter_ns()

    # Get pointer once
    var ptr = data.unsafe_inline_ptr() if data.is_inline() else data.unsafe_heap_ptr()

    for _ in range(iterations):
        # Simulate BPE: for each position, just offset pointer (zero-copy!)
        var pos = data_size // 2
        var remaining = ptr + pos  # No allocation!
        total += Int(remaining[0])

    var elapsed = perf_counter_ns() - start
    return elapsed


# ============================================================================
# Benchmark 3: Comparison Operations (for trie prefix matching)
# ============================================================================

fn bench_list_compare_scalar(iterations: Int, size: Int) -> Int:
    """Benchmark scalar byte comparison using List."""
    var data1 = List[UInt8](capacity=size)
    var data2 = List[UInt8](capacity=size)
    for i in range(size):
        data1.append(UInt8(i % 256))
        data2.append(UInt8(i % 256))

    var matches: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        var equal = True
        for i in range(size):
            if data1[i] != data2[i]:
                equal = False
                break
        if equal:
            matches += 1

    var elapsed = perf_counter_ns() - start
    return elapsed


fn bench_smallvec_compare_simd(iterations: Int, size: Int) -> Int:
    """Benchmark SIMD byte comparison using InlineByteBuffer."""
    var data1 = InlineByteBuffer()
    var data2 = InlineByteBuffer()
    for i in range(size):
        data1.append(UInt8(i % 256))
        data2.append(UInt8(i % 256))

    var matches: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        if data1.simd_equals(data2):
            matches += 1

    var elapsed = perf_counter_ns() - start
    return elapsed


# ============================================================================
# Benchmark 4: Mixed Operations (Realistic BPE Pattern)
# ============================================================================

fn bench_list_bpe_pattern(iterations: Int, text_size: Int) -> Int:
    """Simulate BPE encoding pattern with List (allocates per lookup)."""
    # Create "text" to encode
    var text = List[UInt8](capacity=text_size)
    for i in range(text_size):
        text.append(UInt8(i % 256))

    var tokens: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        var pos = 0
        while pos < text_size:
            # Simulate trie lookup: create slice of remaining text
            var remaining = List[UInt8](capacity=text_size - pos)
            for i in range(pos, min(pos + 10, text_size)):
                remaining.append(text[i])

            # Simulate finding a token (advance by 3 bytes)
            pos += 3
            tokens += 1

    var elapsed = perf_counter_ns() - start
    return elapsed


fn bench_smallvec_bpe_pattern(iterations: Int, text_size: Int) -> Int:
    """Simulate BPE encoding pattern with InlineByteBuffer (zero-copy)."""
    # Create "text" to encode
    var text = InlineByteBuffer()
    for i in range(text_size):
        text.append(UInt8(i % 256))

    var ptr = text.unsafe_inline_ptr() if text.is_inline() else text.unsafe_heap_ptr()

    var tokens: Int = 0
    var start = perf_counter_ns()

    for _ in range(iterations):
        var pos = 0
        while pos < text_size:
            # Simulate trie lookup: just offset pointer (zero-copy!)
            var remaining = ptr + pos  # No allocation!

            # Access first few bytes (simulating prefix match)
            var byte0 = remaining[0]
            var byte1 = remaining[1] if pos + 1 < text_size else UInt8(0)
            var byte2 = remaining[2] if pos + 2 < text_size else UInt8(0)

            # Simulate finding a token (advance by 3 bytes)
            pos += 3
            tokens += 1

    var elapsed = perf_counter_ns() - start
    return elapsed


# ============================================================================
# Main
# ============================================================================

fn format_rate(elapsed_ns: Int, operations: Int) -> String:
    """Format operations per second."""
    if elapsed_ns == 0:
        return "∞ (instant)"
    var ops_per_sec = operations * 1_000_000_000 // elapsed_ns
    if ops_per_sec >= 1_000_000:
        return String(ops_per_sec // 1_000_000) + " M/s"
    elif ops_per_sec >= 1_000:
        return String(ops_per_sec // 1_000) + " K/s"
    return String(ops_per_sec) + " /s"


fn main():
    print("=" * 70)
    print("Benchmark: Mojo List vs mojo-vec InlineByteBuffer")
    print("=" * 70)
    print()

    # Benchmark parameters
    alias ITERATIONS = 10_000
    alias SMALL_SIZE = 32   # Fits in SmallVec inline storage
    alias LARGE_SIZE = 128  # Exceeds inline, uses heap

    # -------------------------------------------------------------------------
    # Benchmark 1: Append Operations
    # -------------------------------------------------------------------------
    print("1. APPEND OPERATIONS (", ITERATIONS, " iterations)")
    print("-" * 50)

    var list_append_small = bench_list_append(ITERATIONS, SMALL_SIZE)
    var smallvec_append_small = bench_smallvec_append(ITERATIONS, SMALL_SIZE)

    print("   Size = ", SMALL_SIZE, " (inline)")
    print("   List[UInt8]:    ", list_append_small // 1_000_000, " ms  ", format_rate(list_append_small, ITERATIONS))
    print("   InlineByteBuffer:   ", smallvec_append_small // 1_000_000, " ms  ", format_rate(smallvec_append_small, ITERATIONS))
    print("   Speedup:        ", list_append_small * 100 // smallvec_append_small / 100, "x")
    print()

    var list_append_large = bench_list_append(ITERATIONS, LARGE_SIZE)
    var smallvec_append_large = bench_smallvec_append(ITERATIONS, LARGE_SIZE)

    print("   Size = ", LARGE_SIZE, " (heap)")
    print("   List[UInt8]:    ", list_append_large // 1_000_000, " ms  ", format_rate(list_append_large, ITERATIONS))
    print("   InlineByteBuffer:   ", smallvec_append_large // 1_000_000, " ms  ", format_rate(smallvec_append_large, ITERATIONS))
    print("   Speedup:        ", list_append_large * 100 // smallvec_append_large / 100, "x")
    print()

    # -------------------------------------------------------------------------
    # Benchmark 2: Slice Operations
    # -------------------------------------------------------------------------
    print("2. SLICE OPERATIONS (", ITERATIONS * 10, " iterations)")
    print("-" * 50)

    alias SLICE_ITERS = ITERATIONS * 10
    alias DATA_SIZE = 1000

    var list_slice = bench_list_slice(SLICE_ITERS, DATA_SIZE)
    var smallvec_slice = bench_smallvec_slice_zerocopy(SLICE_ITERS, DATA_SIZE)

    print("   Data size = ", DATA_SIZE, " bytes, slice at midpoint")
    print("   List (copy):        ", list_slice // 1_000_000, " ms  ", format_rate(list_slice, SLICE_ITERS))
    print("   SmallVec (zero-cp): ", smallvec_slice // 1_000_000, " ms  ", format_rate(smallvec_slice, SLICE_ITERS))

    if smallvec_slice > 0:
        print("   Speedup:            ", list_slice // smallvec_slice, "x")
    else:
        print("   Speedup:            ∞ (zero-copy is instant)")
    print()

    # -------------------------------------------------------------------------
    # Benchmark 3: Comparison Operations
    # -------------------------------------------------------------------------
    print("3. BYTE COMPARISON (", ITERATIONS, " iterations)")
    print("-" * 50)

    alias CMP_SIZE = 64

    var list_cmp = bench_list_compare_scalar(ITERATIONS, CMP_SIZE)
    var smallvec_cmp = bench_smallvec_compare_simd(ITERATIONS, CMP_SIZE)

    print("   Compare ", CMP_SIZE, " bytes")
    print("   List (scalar):      ", list_cmp // 1_000_000, " ms  ", format_rate(list_cmp, ITERATIONS))
    print("   SmallVec (SIMD):    ", smallvec_cmp // 1_000_000, " ms  ", format_rate(smallvec_cmp, ITERATIONS))
    if smallvec_cmp > 0:
        print("   Speedup:            ", list_cmp * 100 // max(smallvec_cmp, 1) / 100, "x")
    else:
        print("   Speedup:            ∞ (SIMD is instant)")
    print()

    # -------------------------------------------------------------------------
    # Benchmark 4: BPE Pattern (Realistic Workload)
    # -------------------------------------------------------------------------
    print("4. BPE ENCODING PATTERN (", ITERATIONS // 10, " iterations)")
    print("-" * 50)

    alias BPE_ITERS = ITERATIONS // 10
    alias TEXT_SIZE = 1000

    var list_bpe = bench_list_bpe_pattern(BPE_ITERS, TEXT_SIZE)
    var smallvec_bpe = bench_smallvec_bpe_pattern(BPE_ITERS, TEXT_SIZE)

    print("   Text size = ", TEXT_SIZE, " bytes")
    print("   List (allocate):    ", list_bpe // 1_000_000, " ms  ", format_rate(list_bpe, BPE_ITERS))
    print("   SmallVec (zero-cp): ", smallvec_bpe // 1_000_000, " ms  ", format_rate(smallvec_bpe, BPE_ITERS))
    if smallvec_bpe > 0:
        print("   Speedup:            ", list_bpe * 100 // max(smallvec_bpe, 1) / 100, "x")
    else:
        print("   Speedup:            ∞ (zero-copy is instant)")
    print()

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print()
    print("InlineByteBuffer advantages over List[UInt8]:")
    print("  - Append (inline):  ", list_append_small * 100 // max(smallvec_append_small, 1) / 100, "x faster (no heap allocation)")
    print("  - Slice:            ", list_slice // max(smallvec_slice, 1), "x faster (zero-copy vs copy)")
    print("  - Comparison:       ", list_cmp * 100 // max(smallvec_cmp, 1) / 100, "x faster (SIMD)")
    print("  - BPE pattern:      ", list_bpe * 100 // max(smallvec_bpe, 1) / 100, "x faster (combined)")
    print()
    print("For Rust Vec comparison, run: python benchmarks/bench_rust_comparison.py")
