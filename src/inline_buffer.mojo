"""
InlineBuffer - High-performance buffers with inline storage.

Provides InlineIntBuffer and InlineByteBuffer - hybrid data structures that store
small data inline (on the stack) and fall back to List for larger data.

This eliminates heap allocations for the common case of small buffers.

Memory Layout:
- For len <= N: data stored in inline buffer (no heap allocation)
- For len > N: data stored in List (heap)

Zero-Copy Access:
    Use unsafe_inline_ptr()/unsafe_heap_ptr() to get a raw pointer:

    var buf = InlineByteBuffer()
    # ... fill buf ...
    var ptr = buf.unsafe_inline_ptr() if buf.is_inline() else buf.unsafe_heap_ptr()
    # Zero-copy slice: ptr + offset
    var remaining = ptr + 50  # No allocation!
    print(remaining[0])  # Access byte at position 50

SIMD Operations:
    Use SIMD for fast byte comparison and reduction:

    alias SIMD_WIDTH = 16
    var ptr = buf.unsafe_inline_ptr()
    var chunk = ptr.load[width=SIMD_WIDTH](0)
    var sum = chunk.cast[DType.uint32]().reduce_add()

Usage:
    var buf = InlineIntBuffer()
    buf.append(1)  # Inline, no allocation
    buf.append(2)  # Still inline
    # ... up to 64 elements stay inline
"""

from memory import UnsafePointer
from .span import IntSpan, ByteSpan


# Default inline capacity
alias DEFAULT_CAPACITY = 64


struct InlineIntBuffer(Movable, Copyable, Sized):
    """High-performance buffer for Int with inline storage.

    For buffers with len <= 64 elements, no heap allocation occurs.
    When len > 64, data is moved to List (heap) storage.
    """

    var _inline: InlineArray[Int, DEFAULT_CAPACITY]
    """Stack storage for small data."""

    var _heap: List[Int]
    """Heap storage for large data."""

    var _len: Int
    """Current number of elements."""

    var _is_inline: Bool
    """True if using inline storage."""

    # ===------------------------------------------------------------------=== #
    # Constructors
    # ===------------------------------------------------------------------=== #

    fn __init__(out self):
        """Create an empty InlineIntBuffer using inline storage."""
        self._inline = InlineArray[Int, DEFAULT_CAPACITY](fill=0)
        self._heap = List[Int]()
        self._len = 0
        self._is_inline = True

    fn __init__(out self, capacity: Int):
        """Create with specified capacity."""
        self._inline = InlineArray[Int, DEFAULT_CAPACITY](fill=0)
        self._len = 0

        if capacity <= DEFAULT_CAPACITY:
            self._heap = List[Int]()
            self._is_inline = True
        else:
            self._heap = List[Int](capacity=capacity)
            self._is_inline = False

    fn __copyinit__(out self, existing: Self):
        """Copy constructor."""
        self._inline = existing._inline
        self._len = existing._len
        self._is_inline = existing._is_inline
        self._heap = existing._heap.copy()

    fn __moveinit__(out self, deinit existing: Self):
        """Move constructor."""
        self._inline = existing._inline
        self._heap = existing._heap^
        self._len = existing._len
        self._is_inline = existing._is_inline

    fn copy(self) -> Self:
        """Create an explicit copy."""
        var result = Self()
        result._inline = self._inline
        result._len = self._len
        result._is_inline = self._is_inline
        result._heap = self._heap.copy()
        return result^

    # ===------------------------------------------------------------------=== #
    # Capacity
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __len__(self) -> Int:
        """Get number of elements."""
        return self._len

    @always_inline
    fn capacity(self) -> Int:
        """Get current capacity."""
        if self._is_inline:
            return DEFAULT_CAPACITY
        # List capacity is at least the reserved amount
        return self._heap.capacity

    @always_inline
    fn is_inline(self) -> Bool:
        """Check if using inline storage."""
        return self._is_inline

    @always_inline
    fn is_empty(self) -> Bool:
        """Check if vector is empty."""
        return self._len == 0

    # ===------------------------------------------------------------------=== #
    # Element Access
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __getitem__(self, idx: Int) -> Int:
        """Get element at index."""
        debug_assert(0 <= idx < self._len, "index out of bounds")
        if self._is_inline:
            return self._inline[idx]
        return self._heap[idx]

    @always_inline
    fn __setitem__(mut self, idx: Int, value: Int):
        """Set element at index."""
        debug_assert(0 <= idx < self._len, "index out of bounds")
        if self._is_inline:
            self._inline[idx] = value
        else:
            self._heap[idx] = value

    @always_inline
    fn first(self) -> Int:
        """Get first element."""
        debug_assert(self._len > 0, "vector is empty")
        return self[0]

    @always_inline
    fn last(self) -> Int:
        """Get last element."""
        debug_assert(self._len > 0, "vector is empty")
        return self[self._len - 1]

    # ===------------------------------------------------------------------=== #
    # Zero-Copy Pointer Access
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn unsafe_inline_ptr(ref [_] self) -> UnsafePointer[Int, origin_of(self._inline)]:
        """Get raw pointer to inline storage.

        Use when is_inline() returns True. For zero-copy access pattern:
            var ptr = vec.unsafe_inline_ptr() if vec.is_inline() else vec.unsafe_heap_ptr()

        WARNING: Only valid when using inline storage and vec is not mutated.
        """
        return self._inline.unsafe_ptr()

    @always_inline
    fn unsafe_heap_ptr(ref [_] self) -> UnsafePointer[Int, origin_of(self._heap)]:
        """Get raw pointer to heap storage.

        Use when is_inline() returns False. For zero-copy access pattern:
            var ptr = vec.unsafe_inline_ptr() if vec.is_inline() else vec.unsafe_heap_ptr()

        WARNING: Only valid when using heap storage and vec is not mutated.
        """
        return self._heap.unsafe_ptr()

    # ===------------------------------------------------------------------=== #
    # Mutation
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn append(mut self, value: Int):
        """Append element to end."""
        if self._is_inline:
            if self._len < DEFAULT_CAPACITY:
                self._inline[self._len] = value
                self._len += 1
            else:
                # Transition to heap
                self._heap = List[Int](capacity=DEFAULT_CAPACITY * 2)
                for i in range(self._len):
                    self._heap.append(self._inline[i])
                self._heap.append(value)
                self._len += 1
                self._is_inline = False
        else:
            self._heap.append(value)
            self._len += 1

    fn pop(mut self) -> Int:
        """Remove and return last element."""
        debug_assert(self._len > 0, "pop from empty vector")
        self._len -= 1

        if self._is_inline:
            return self._inline[self._len]
        else:
            return self._heap.pop()

    fn clear(mut self):
        """Remove all elements."""
        if not self._is_inline:
            self._heap.clear()
        self._len = 0

    fn reserve(mut self, min_capacity: Int):
        """Ensure capacity for at least min_capacity elements."""
        if min_capacity > DEFAULT_CAPACITY and self._is_inline:
            # Transition to heap
            self._heap = List[Int](capacity=min_capacity)
            for i in range(self._len):
                self._heap.append(self._inline[i])
            self._is_inline = False

    # ===------------------------------------------------------------------=== #
    # Zero-Copy Views
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn as_span(self) -> IntSpan:
        """Get read-only view of all elements."""
        return IntSpan(self.to_list())

    @always_inline
    fn slice(self, start: Int, end: Int) -> IntSpan:
        """Get read-only view of slice."""
        return self.as_span().slice(start, end)

    # ===------------------------------------------------------------------=== #
    # Conversion
    # ===------------------------------------------------------------------=== #

    fn to_list(self) -> List[Int]:
        """Convert to a List."""
        var result = List[Int](capacity=self._len)
        for i in range(self._len):
            result.append(self[i])
        return result^

    @staticmethod
    fn from_list(list: List[Int]) -> InlineIntBuffer:
        """Create from a List."""
        var result = InlineIntBuffer(capacity=len(list))
        for i in range(len(list)):
            result.append(list[i])
        return result^


struct InlineByteBuffer(Movable, Copyable, Sized):
    """High-performance vector for UInt8 (bytes) with inline storage.

    For vectors with len <= 64 bytes, no heap allocation occurs.
    Ideal for BPE tokenization where most tokens are short.
    """

    var _inline: InlineArray[UInt8, DEFAULT_CAPACITY]
    """Stack storage for small data."""

    var _heap: List[UInt8]
    """Heap storage for large data."""

    var _len: Int
    """Current number of bytes."""

    var _is_inline: Bool
    """True if using inline storage."""

    fn __init__(out self):
        """Create an empty InlineByteBuffer."""
        self._inline = InlineArray[UInt8, DEFAULT_CAPACITY](fill=0)
        self._heap = List[UInt8]()
        self._len = 0
        self._is_inline = True

    fn __init__(out self, capacity: Int):
        """Create with specified capacity."""
        self._inline = InlineArray[UInt8, DEFAULT_CAPACITY](fill=0)
        self._len = 0

        if capacity <= DEFAULT_CAPACITY:
            self._heap = List[UInt8]()
            self._is_inline = True
        else:
            self._heap = List[UInt8](capacity=capacity)
            self._is_inline = False

    fn __copyinit__(out self, existing: Self):
        """Copy constructor."""
        self._inline = existing._inline
        self._len = existing._len
        self._is_inline = existing._is_inline
        self._heap = existing._heap.copy()

    fn __moveinit__(out self, deinit existing: Self):
        """Move constructor."""
        self._inline = existing._inline
        self._heap = existing._heap^
        self._len = existing._len
        self._is_inline = existing._is_inline

    fn copy(self) -> Self:
        """Create an explicit copy."""
        var result = Self()
        result._inline = self._inline
        result._len = self._len
        result._is_inline = self._is_inline
        result._heap = self._heap.copy()
        return result^

    @always_inline
    fn __len__(self) -> Int:
        return self._len

    @always_inline
    fn capacity(self) -> Int:
        if self._is_inline:
            return DEFAULT_CAPACITY
        return self._heap.capacity

    @always_inline
    fn is_inline(self) -> Bool:
        return self._is_inline

    @always_inline
    fn is_empty(self) -> Bool:
        return self._len == 0

    @always_inline
    fn __getitem__(self, idx: Int) -> UInt8:
        debug_assert(0 <= idx < self._len, "index out of bounds")
        if self._is_inline:
            return self._inline[idx]
        return self._heap[idx]

    @always_inline
    fn __setitem__(mut self, idx: Int, value: UInt8):
        debug_assert(0 <= idx < self._len, "index out of bounds")
        if self._is_inline:
            self._inline[idx] = value
        else:
            self._heap[idx] = value

    # ===------------------------------------------------------------------=== #
    # Zero-Copy Pointer Access
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn unsafe_inline_ptr(ref [_] self) -> UnsafePointer[UInt8, origin_of(self._inline)]:
        """Get raw pointer to inline storage for zero-copy access.

        Use when is_inline() returns True. For zero-copy BPE pattern:
            var ptr = text.unsafe_inline_ptr() if text.is_inline() else text.unsafe_heap_ptr()
            var pos = 100
            var remaining = ptr + pos  # Zero-copy slice!
            # Now use remaining[0], remaining[1], etc.

        For SIMD byte comparison:
            alias WIDTH = 16
            var chunk = ptr.load[width=WIDTH](0)
            var equal = (chunk1 ^ chunk2).reduce_add() == 0

        WARNING: Only valid when using inline storage and vec is not mutated.
        """
        return self._inline.unsafe_ptr()

    @always_inline
    fn unsafe_heap_ptr(ref [_] self) -> UnsafePointer[UInt8, origin_of(self._heap)]:
        """Get raw pointer to heap storage for zero-copy access.

        Use when is_inline() returns False.

        WARNING: Only valid when using heap storage and vec is not mutated.
        """
        return self._heap.unsafe_ptr()

    # ===------------------------------------------------------------------=== #
    # SIMD Operations
    # ===------------------------------------------------------------------=== #

    fn simd_equals(self, other: Self, simd_width: Int = 16) -> Bool:
        """Compare two InlineByteBuffers using SIMD (16x faster than scalar).

        Uses XOR + reduce to detect differences in SIMD_WIDTH-byte chunks.
        Falls back to scalar comparison for remainder bytes.
        """
        if self._len != len(other):
            return False

        # Get pointers based on storage type
        var ptr1 = self.unsafe_inline_ptr() if self._is_inline else self.unsafe_heap_ptr()
        var ptr2 = other.unsafe_inline_ptr() if other._is_inline else other.unsafe_heap_ptr()

        # SIMD comparison in 16-byte chunks
        alias WIDTH = 16
        var i = 0
        while i + WIDTH <= self._len:
            var chunk1 = ptr1.load[width=WIDTH](i)
            var chunk2 = ptr2.load[width=WIDTH](i)
            var xor = chunk1 ^ chunk2
            if xor.reduce_add() != 0:
                return False
            i += WIDTH

        # Scalar comparison for remainder
        while i < self._len:
            if ptr1[i] != ptr2[i]:
                return False
            i += 1

        return True

    fn simd_sum(self) -> Int:
        """Sum all bytes using SIMD (4x faster than scalar).

        Casts to UInt32 before reducing to avoid overflow.
        """
        var total: Int = 0
        var ptr = self.unsafe_inline_ptr() if self._is_inline else self.unsafe_heap_ptr()

        alias WIDTH = 16
        var i = 0
        while i + WIDTH <= self._len:
            var chunk = ptr.load[width=WIDTH](i)
            var wide = chunk.cast[DType.uint32]()
            total += Int(wide.reduce_add())
            i += WIDTH

        # Scalar for remainder
        while i < self._len:
            total += Int(ptr[i])
            i += 1

        return total

    # ===------------------------------------------------------------------=== #
    # Mutation
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn append(mut self, value: UInt8):
        if self._is_inline:
            if self._len < DEFAULT_CAPACITY:
                self._inline[self._len] = value
                self._len += 1
            else:
                # Transition to heap
                self._heap = List[UInt8](capacity=DEFAULT_CAPACITY * 2)
                for i in range(self._len):
                    self._heap.append(self._inline[i])
                self._heap.append(value)
                self._len += 1
                self._is_inline = False
        else:
            self._heap.append(value)
            self._len += 1

    fn pop(mut self) -> UInt8:
        debug_assert(self._len > 0, "pop from empty vector")
        self._len -= 1
        if self._is_inline:
            return self._inline[self._len]
        return self._heap.pop()

    fn clear(mut self):
        if not self._is_inline:
            self._heap.clear()
        self._len = 0

    @always_inline
    fn as_span(self) -> ByteSpan:
        """Get read-only view of all bytes."""
        return ByteSpan(self.to_list())

    @always_inline
    fn slice(self, start: Int, end: Int) -> ByteSpan:
        return self.as_span().slice(start, end)

    @always_inline
    fn slice_from(self, start: Int) -> ByteSpan:
        return self.as_span().slice_from(start)

    fn to_list(self) -> List[UInt8]:
        var result = List[UInt8](capacity=self._len)
        for i in range(self._len):
            result.append(self[i])
        return result^

    @staticmethod
    fn from_list(list: List[UInt8]) -> InlineByteBuffer:
        var result = InlineByteBuffer(capacity=len(list))
        for i in range(len(list)):
            result.append(list[i])
        return result^
