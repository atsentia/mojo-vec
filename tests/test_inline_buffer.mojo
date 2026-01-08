"""
Unit tests for InlineIntBuffer and InlineByteBuffer.
"""

from testing import assert_equal, assert_true, assert_false
from src.inline_buffer import InlineIntBuffer, InlineByteBuffer
from src.span import IntSpan, ByteSpan


fn test_empty_inline_int_buffer() raises:
    """Test empty InlineIntBuffer initialization."""
    var vec = InlineIntBuffer()
    assert_equal(len(vec), 0)
    assert_equal(vec.capacity(), 64)
    assert_true(vec.is_inline())
    assert_true(vec.is_empty())
    print("✓ test_empty_inline_int_buffer")


fn test_append_inline() raises:
    """Test appending elements within inline capacity."""
    var vec = InlineIntBuffer()
    for i in range(8):
        vec.append(i)

    assert_equal(len(vec), 8)
    assert_true(vec.is_inline())

    for i in range(8):
        assert_equal(vec[i], i)
    print("✓ test_append_inline")


fn test_append_triggers_heap() raises:
    """Test that exceeding inline capacity triggers heap allocation."""
    var vec = InlineIntBuffer()

    # Fill inline storage (64 elements)
    for i in range(64):
        vec.append(i)
    assert_true(vec.is_inline())

    # Add one more - triggers heap allocation
    vec.append(64)
    assert_false(vec.is_inline())
    assert_equal(len(vec), 65)

    # Verify all elements preserved
    for i in range(65):
        assert_equal(vec[i], i)
    print("✓ test_append_triggers_heap")


fn test_pop() raises:
    """Test pop operation."""
    var vec = InlineIntBuffer()
    vec.append(1)
    vec.append(2)
    vec.append(3)

    assert_equal(vec.pop(), 3)
    assert_equal(len(vec), 2)
    assert_equal(vec.pop(), 2)
    assert_equal(len(vec), 1)
    assert_equal(vec.pop(), 1)
    assert_equal(len(vec), 0)
    print("✓ test_pop")


fn test_getitem_setitem() raises:
    """Test element access and modification."""
    var vec = InlineIntBuffer()
    vec.append(10)
    vec.append(20)
    vec.append(30)

    assert_equal(vec[0], 10)
    assert_equal(vec[1], 20)
    assert_equal(vec[2], 30)

    vec[1] = 200
    assert_equal(vec[1], 200)
    print("✓ test_getitem_setitem")


fn test_first_last() raises:
    """Test first() and last() methods."""
    var vec = InlineIntBuffer()
    vec.append(1)
    vec.append(2)
    vec.append(3)

    assert_equal(vec.first(), 1)
    assert_equal(vec.last(), 3)
    print("✓ test_first_last")


fn test_clear() raises:
    """Test clear operation."""
    var vec = InlineIntBuffer()
    vec.append(1)
    vec.append(2)
    vec.append(3)

    vec.clear()
    assert_equal(len(vec), 0)
    assert_true(vec.is_empty())

    vec.append(100)
    assert_equal(vec[0], 100)
    print("✓ test_clear")


fn test_copy() raises:
    """Test copy semantics."""
    var vec1 = InlineIntBuffer()
    vec1.append(1)
    vec1.append(2)

    var vec2 = vec1.copy()

    vec1[0] = 100

    assert_equal(vec2[0], 1)
    assert_equal(vec1[0], 100)
    print("✓ test_copy")


fn test_as_span() raises:
    """Test as_span() zero-copy view."""
    var vec = InlineIntBuffer()
    vec.append(1)
    vec.append(2)
    vec.append(3)

    var span = vec.as_span()
    assert_equal(len(span), 3)
    assert_equal(span[0], 1)
    assert_equal(span[1], 2)
    assert_equal(span[2], 3)
    print("✓ test_as_span")


fn test_slice() raises:
    """Test slice() zero-copy view."""
    var vec = InlineIntBuffer()
    for i in range(5):
        vec.append(i)

    var sl = vec.slice(1, 4)
    assert_equal(len(sl), 3)
    assert_equal(sl[0], 1)
    assert_equal(sl[1], 2)
    assert_equal(sl[2], 3)
    print("✓ test_slice")


fn test_reserve() raises:
    """Test reserve() capacity."""
    var vec = InlineIntBuffer()

    # Reserve more than inline capacity
    vec.reserve(100)
    assert_false(vec.is_inline())
    assert_true(vec.capacity() >= 100)

    for i in range(100):
        vec.append(i)
    assert_equal(len(vec), 100)
    print("✓ test_reserve")


fn test_to_list() raises:
    """Test conversion to List."""
    var vec = InlineIntBuffer()
    vec.append(1)
    vec.append(2)
    vec.append(3)

    var list = vec.to_list()
    assert_equal(len(list), 3)
    assert_equal(list[0], 1)
    assert_equal(list[1], 2)
    assert_equal(list[2], 3)
    print("✓ test_to_list")


fn test_from_list() raises:
    """Test creation from List."""
    var list = List[Int](1, 2, 3)
    var vec = InlineIntBuffer.from_list(list)

    assert_equal(len(vec), 3)
    assert_equal(vec[0], 1)
    assert_equal(vec[1], 2)
    assert_equal(vec[2], 3)
    print("✓ test_from_list")


fn test_heap_growth() raises:
    """Test heap growth strategy (2x)."""
    var vec = InlineIntBuffer()

    # Fill inline (64)
    for i in range(64):
        vec.append(i)
    assert_true(vec.is_inline())

    # Trigger heap (64 * 2 = 128)
    vec.append(64)
    assert_false(vec.is_inline())
    assert_true(vec.capacity() >= 128)

    # Keep growing
    for i in range(200):
        vec.append(i)

    assert_equal(len(vec), 265)
    print("✓ test_heap_growth")


fn test_inline_byte_buffer() raises:
    """Test InlineByteBuffer basic operations."""
    var vec = InlineByteBuffer()
    vec.append(UInt8(1))
    vec.append(UInt8(2))
    vec.append(UInt8(3))

    assert_equal(len(vec), 3)
    assert_equal(vec[0], UInt8(1))
    assert_equal(vec[1], UInt8(2))
    assert_equal(vec[2], UInt8(3))

    var span = vec.as_span()
    assert_equal(len(span), 3)

    var sl = vec.slice(1, 3)
    assert_equal(len(sl), 2)
    assert_equal(sl[0], UInt8(2))
    print("✓ test_inline_byte_buffer")


fn test_unsafe_ptr_int() raises:
    """Test unsafe_ptr for InlineIntBuffer - zero-copy access."""
    var vec = InlineIntBuffer()
    for i in range(10):
        vec.append(i * 10)

    # Get raw pointer (using inline since len < 64)
    assert_true(vec.is_inline())
    var ptr = vec.unsafe_inline_ptr()

    # Direct access via pointer
    assert_equal(ptr[0], 0)
    assert_equal(ptr[5], 50)
    assert_equal(ptr[9], 90)

    # Pointer arithmetic (zero-copy slice)
    var ptr3 = ptr + 3
    assert_equal(ptr3[0], 30)
    assert_equal(ptr3[1], 40)

    print("✓ test_unsafe_ptr_int")


fn test_unsafe_ptr_byte() raises:
    """Test unsafe_ptr for InlineByteBuffer - zero-copy access."""
    var vec = InlineByteBuffer()
    for i in range(50):
        vec.append(UInt8(i))

    # Using inline since len < 64
    assert_true(vec.is_inline())
    var ptr = vec.unsafe_inline_ptr()

    # Direct access
    assert_equal(ptr[0], UInt8(0))
    assert_equal(ptr[25], UInt8(25))
    assert_equal(ptr[49], UInt8(49))

    # Zero-copy slice via pointer arithmetic (key BPE optimization!)
    var pos = 20
    var remaining = ptr + pos
    assert_equal(remaining[0], UInt8(20))
    assert_equal(remaining[10], UInt8(30))

    print("✓ test_unsafe_ptr_byte")


fn test_unsafe_ptr_heap() raises:
    """Test unsafe_ptr works after heap transition."""
    var vec = InlineByteBuffer()

    # Fill past inline capacity
    for i in range(100):
        vec.append(UInt8(i % 256))

    assert_false(vec.is_inline())

    # Using heap since len > 64
    var ptr = vec.unsafe_heap_ptr()
    assert_equal(ptr[0], UInt8(0))
    assert_equal(ptr[50], UInt8(50))
    assert_equal(ptr[99], UInt8(99))

    print("✓ test_unsafe_ptr_heap")


fn test_simd_equals() raises:
    """Test SIMD-accelerated equality comparison."""
    var vec1 = InlineByteBuffer()
    var vec2 = InlineByteBuffer()

    for i in range(64):
        vec1.append(UInt8(i))
        vec2.append(UInt8(i))

    # Should be equal
    assert_true(vec1.simd_equals(vec2))

    # Modify one byte
    vec2[30] = UInt8(255)
    assert_false(vec1.simd_equals(vec2))

    # Different lengths
    var vec3 = InlineByteBuffer()
    for i in range(32):
        vec3.append(UInt8(i))
    assert_false(vec1.simd_equals(vec3))

    print("✓ test_simd_equals")


fn test_simd_sum() raises:
    """Test SIMD-accelerated sum."""
    var vec = InlineByteBuffer()

    # 0 + 1 + 2 + ... + 63 = 2016
    for i in range(64):
        vec.append(UInt8(i))

    assert_equal(vec.simd_sum(), 2016)

    # Test with non-SIMD-aligned length
    var vec2 = InlineByteBuffer()
    for i in range(17):  # Not divisible by 16
        vec2.append(UInt8(i))
    # 0 + 1 + ... + 16 = 136
    assert_equal(vec2.simd_sum(), 136)

    print("✓ test_simd_sum")


fn test_simd_load() raises:
    """Test SIMD load operations via unsafe_ptr."""
    var vec = InlineByteBuffer()
    for i in range(32):
        vec.append(UInt8(i))

    # Using inline since len < 64
    assert_true(vec.is_inline())
    var ptr = vec.unsafe_inline_ptr()

    # Load 16 bytes at once
    alias WIDTH = 16
    var chunk = ptr.load[width=WIDTH](0)

    # Verify first chunk has values 0-15
    var sum = chunk.cast[DType.uint32]().reduce_add()
    # 0+1+2+...+15 = 120
    assert_equal(Int(sum), 120)

    # Load second chunk
    var chunk2 = ptr.load[width=WIDTH](16)
    var sum2 = chunk2.cast[DType.uint32]().reduce_add()
    # 16+17+...+31 = 376
    assert_equal(Int(sum2), 376)

    print("✓ test_simd_load")


fn main() raises:
    """Run all InlineBuffer tests."""
    print("Running mojo-vec tests...\n")

    # Core InlineBuffer tests
    test_empty_inline_int_buffer()
    test_append_inline()
    test_append_triggers_heap()
    test_pop()
    test_getitem_setitem()
    test_first_last()
    test_clear()
    test_copy()
    test_as_span()
    test_slice()
    test_reserve()
    test_to_list()
    test_from_list()
    test_heap_growth()
    test_inline_byte_buffer()

    # Zero-copy pointer access tests
    test_unsafe_ptr_int()
    test_unsafe_ptr_byte()
    test_unsafe_ptr_heap()

    # SIMD operation tests
    test_simd_equals()
    test_simd_sum()
    test_simd_load()

    print("\n✅ All mojo-vec tests passed!")
