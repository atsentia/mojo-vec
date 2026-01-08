"""
Unit tests for Span[T].
"""

from testing import assert_equal, assert_true, assert_false
from memory import UnsafePointer
from src.span import Span


fn test_empty_span() raises:
    """Test empty Span initialization."""
    var span = Span[Int]()
    assert_equal(len(span), 0)
    assert_true(span.is_empty())
    print("✓ test_empty_span")


fn test_span_from_list() raises:
    """Test creating Span from List."""
    var list = List[Int](1, 2, 3, 4, 5)
    var span = Span.from_list(list)

    assert_equal(len(span), 5)
    assert_equal(span[0], 1)
    assert_equal(span[1], 2)
    assert_equal(span[4], 5)

    print("✓ test_span_from_list")


fn test_span_slice() raises:
    """Test zero-copy slicing."""
    var list = List[Int](10, 20, 30, 40, 50)
    var span = Span.from_list(list)

    var sub = span.slice(1, 4)
    assert_equal(len(sub), 3)
    assert_equal(sub[0], 20)
    assert_equal(sub[1], 30)
    assert_equal(sub[2], 40)

    print("✓ test_span_slice")


fn test_span_slice_from() raises:
    """Test slice_from."""
    var list = List[Int](1, 2, 3, 4, 5)
    var span = Span.from_list(list)

    var sub = span.slice_from(2)
    assert_equal(len(sub), 3)
    assert_equal(sub[0], 3)
    assert_equal(sub[1], 4)
    assert_equal(sub[2], 5)

    print("✓ test_span_slice_from")


fn test_span_slice_to() raises:
    """Test slice_to."""
    var list = List[Int](1, 2, 3, 4, 5)
    var span = Span.from_list(list)

    var sub = span.slice_to(3)
    assert_equal(len(sub), 3)
    assert_equal(sub[0], 1)
    assert_equal(sub[1], 2)
    assert_equal(sub[2], 3)

    print("✓ test_span_slice_to")


fn test_span_first_last() raises:
    """Test first() and last()."""
    var list = List[Int](10, 20, 30)
    var span = Span.from_list(list)

    assert_equal(span.first(), 10)
    assert_equal(span.last(), 30)

    print("✓ test_span_first_last")


fn test_span_nested_slice() raises:
    """Test slicing a slice (still zero-copy)."""
    var list = List[Int](0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
    var span = Span.from_list(list)

    var sub1 = span.slice(2, 8)  # [2, 3, 4, 5, 6, 7]
    assert_equal(len(sub1), 6)

    var sub2 = sub1.slice(1, 4)  # [3, 4, 5]
    assert_equal(len(sub2), 3)
    assert_equal(sub2[0], 3)
    assert_equal(sub2[1], 4)
    assert_equal(sub2[2], 5)

    print("✓ test_span_nested_slice")


fn test_span_to_list() raises:
    """Test conversion back to List."""
    var original = List[Int](1, 2, 3)
    var span = Span.from_list(original)
    var sub = span.slice(1, 3)

    var result = sub.to_list()
    assert_equal(len(result), 2)
    assert_equal(result[0], 2)
    assert_equal(result[1], 3)

    print("✓ test_span_to_list")


fn test_span_copy() raises:
    """Test Span copy semantics (cheap - just ptr + len)."""
    var list = List[Int](1, 2, 3)
    var span1 = Span.from_list(list)
    var span2 = span1  # Copy

    # Both point to same data
    assert_equal(span1[0], span2[0])
    assert_equal(span1.unsafe_ptr(), span2.unsafe_ptr())

    print("✓ test_span_copy")


fn test_span_unsafe_get() raises:
    """Test unsafe_get (no bounds checking)."""
    var list = List[Int](100, 200, 300)
    var span = Span.from_list(list)

    assert_equal(span.unsafe_get(0), 100)
    assert_equal(span.unsafe_get(1), 200)
    assert_equal(span.unsafe_get(2), 300)

    print("✓ test_span_unsafe_get")


fn main() raises:
    """Run all Span tests."""
    print("Running Span tests...\n")

    test_empty_span()
    test_span_from_list()
    test_span_slice()
    test_span_slice_from()
    test_span_slice_to()
    test_span_first_last()
    test_span_nested_slice()
    test_span_to_list()
    test_span_copy()
    test_span_unsafe_get()

    print("\n✅ All Span tests passed!")
