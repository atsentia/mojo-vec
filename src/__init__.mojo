"""
mojo-vec: High-Performance Buffers for Mojo

Provides InlineIntBuffer and InlineByteBuffer - hybrid buffers that store small data
inline (no heap allocation) and fall back to heap for larger data.

Also provides ByteSpan and IntSpan - read-only views (placeholder implementation).

Usage:
    from src import InlineIntBuffer, InlineByteBuffer, ByteSpan, IntSpan

    # InlineBuffer with inline storage (no allocation for len <= 64)
    var buf = InlineIntBuffer()
    buf.append(1)
    buf.append(2)

    # Zero-copy access via pointer
    var ptr = buf.unsafe_inline_ptr()
    print(ptr[0])  # Direct access, no copy
"""

from .span import ByteSpan, IntSpan
from .inline_buffer import InlineIntBuffer, InlineByteBuffer
