"""UUID version 7 (time-ordered) generation per RFC 9562.

UUID v7 embeds a Unix millisecond timestamp in the high bits, making UUIDs
naturally sortable by creation time. The bit layout is:

    Bits  0-47  : Unix timestamp in milliseconds (big-endian, 48 bits)
    Bits 48-51  : Version field = 0111 (version 7)
    Bits 52-63  : rand_a: 12 random bits
    Bits 64-65  : Variant field = 10 (RFC 9562)
    Bits 66-127 : rand_b: 62 random bits

The timestamp is obtained via the `gettimeofday` libc function (FFI), which
provides microsecond resolution. Only milliseconds are stored in the UUID.

The `uuid7()` free function generates a stateless v7 UUID. For strict
sub-millisecond monotonicity across successive calls, use `V7Generator`:

    var gen = V7Generator()
    var a = gen.generate()
    var b = gen.generate()
    # a < b is guaranteed even within the same millisecond.

Example:

    from uuid import uuid7

    var a = uuid7()
    var b = uuid7()
    print(a.version())  # 7
"""

from std.random import random_ui64
from std.ffi import external_call
from uuid.core import UUID


struct _Timeval:
    """POSIX timeval structure for gettimeofday."""

    var tv_sec: Int64
    """Seconds since the Unix epoch."""

    var tv_usec: Int64
    """Microseconds component."""

    def __init__(out self):
        self.tv_sec = 0
        self.tv_usec = 0


@always_inline
def _millis_since_epoch() -> UInt64:
    """Return the current Unix timestamp in milliseconds via libc gettimeofday.

    Returns:
        Milliseconds elapsed since 1970-01-01T00:00:00Z.
    """
    var tv = _Timeval()
    # Pass null (0) for the timezone argument (unused).
    _ = external_call["gettimeofday", Int32](UnsafePointer(to=tv), Int64(0))
    return UInt64(tv.tv_sec) * 1000 + UInt64(tv.tv_usec) // 1000


@always_inline
def _pack_v7(ms: UInt64, rand_a: UInt16, rand_b: UInt64) -> UUID:
    """Pack timestamp and random fields into a v7 UUID byte vector.

    Args:
        ms: Unix timestamp in milliseconds (48 bits used).
        rand_a: 12-bit rand_a field.
        rand_b: 62-bit rand_b field.

    Returns:
        A fully constructed UUID v7.
    """
    var b = SIMD[DType.uint8, 16]()

    # Bytes 0-5: 48-bit timestamp (big-endian).
    b[0] = UInt8((ms >> 40) & 0xFF)
    b[1] = UInt8((ms >> 32) & 0xFF)
    b[2] = UInt8((ms >> 24) & 0xFF)
    b[3] = UInt8((ms >> 16) & 0xFF)
    b[4] = UInt8((ms >> 8) & 0xFF)
    b[5] = UInt8(ms & 0xFF)

    # Byte 6: version (0111) in high nibble, rand_a[11:8] in low nibble.
    b[6] = 0x70 | UInt8((rand_a >> 8) & 0x0F)

    # Byte 7: rand_a[7:0].
    b[7] = UInt8(rand_a & 0xFF)

    # Byte 8: variant (10) in high 2 bits, rand_b[61:56] in low 6 bits.
    b[8] = 0x80 | UInt8((rand_b >> 58) & 0x3F)

    # Bytes 9-15: remaining 56 bits of rand_b.
    for i in range(7):
        b[9 + i] = UInt8((rand_b >> UInt64(48 - i * 8)) & 0xFF)

    return UUID(b)


def uuid7() -> UUID:
    """Generate a time-ordered UUID version 7 per RFC 9562.

    Embeds a 48-bit Unix millisecond timestamp, a 12-bit `rand_a` field, and
    62 random bits. This function is stateless; for strict sub-millisecond
    monotonicity across successive calls, use `V7Generator` instead.

    Returns:
        A new UUID with version=7, variant=2 (RFC 9562), and a timestamp
        equal to the current Unix time in milliseconds.

    Example:

        var a = uuid7()
        var b = uuid7()
        print(a.version())  # 7
    """
    var ms = _millis_since_epoch()
    var rand_a = UInt16(random_ui64(0, 0x0FFF) & 0x0FFF)
    var rand_b = random_ui64(0, UInt64.MAX)
    return _pack_v7(ms, rand_a, rand_b)


struct V7Generator:
    """Stateful UUID v7 generator that guarantees strict monotonic ordering.

    Maintains a last-seen millisecond timestamp and a `rand_a` counter.
    Within the same millisecond, the counter is incremented so successive
    UUIDs remain strictly ordered even at sub-millisecond call rates.

    Example:

        var gen = V7Generator()
        var a = gen.generate()
        var b = gen.generate()
        # String(a) < String(b) is guaranteed.
    """

    var _last_ms: UInt64
    """Last emitted timestamp in milliseconds."""

    var _rand_a: UInt16
    """Monotonicity counter for the rand_a field."""

    def __init__(out self):
        """Initialize the generator with zeroed state."""
        self._last_ms = 0
        self._rand_a = 0

    def generate(mut self) -> UUID:
        """Generate the next monotonically ordered UUID v7.

        Returns:
            A UUID v7 that compares greater than all UUIDs previously
            emitted by this generator instance.
        """
        var ms = _millis_since_epoch()
        if ms <= self._last_ms:
            ms = self._last_ms
            self._rand_a = self._rand_a + 1
        else:
            self._last_ms = ms
            self._rand_a = UInt16(random_ui64(0, 0x0FFF) & 0x0FFF)
        var rand_b = random_ui64(0, UInt64.MAX)
        return _pack_v7(ms, self._rand_a, rand_b)


def uuid7_extract_ms(u: UUID) -> UInt64:
    """Extract the Unix millisecond timestamp embedded in a v7 UUID.

    Reads the 48-bit timestamp from bytes 0-5 of the UUID.

    Args:
        u: A UUID version 7 value.

    Returns:
        The Unix timestamp in milliseconds encoded in the UUID.

    Example:

        var id = uuid7()
        var ms = uuid7_extract_ms(id)
        print(ms)  # e.g. 1704067200000
    """
    var ms: UInt64 = 0
    ms = ms | (UInt64(u.bytes[0]) << 40)
    ms = ms | (UInt64(u.bytes[1]) << 32)
    ms = ms | (UInt64(u.bytes[2]) << 24)
    ms = ms | (UInt64(u.bytes[3]) << 16)
    ms = ms | (UInt64(u.bytes[4]) << 8)
    ms = ms | UInt64(u.bytes[5])
    return ms
