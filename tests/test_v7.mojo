"""Tests for UUID v7 (time-ordered) generation."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from uuid.core import UUID
from uuid.v7 import uuid7, uuid7_extract_ms, V7Generator

# =============================================================================
# Version and variant bits
# =============================================================================


def test_uuid7_version() raises:
    """Always produces a UUID with version == 7."""
    for _ in range(10):
        var u = uuid7()
        assert_equal(u.version(), 7, "version must be 7")


def test_uuid7_variant() raises:
    """Always produces a UUID with RFC 9562 variant (2 = 0b10)."""
    for _ in range(10):
        var u = uuid7()
        assert_equal(u.variant(), 2, "variant must be 2 (RFC 9562)")


def test_uuid7_byte6_high_nibble() raises:
    """Sets the high nibble of byte 6 to 0x7."""
    for _ in range(10):
        var u = uuid7()
        assert_equal(Int(u.bytes[6] >> 4), 7, "byte6 high nibble == 7")


def test_uuid7_byte8_high_bits() raises:
    """Sets the high 2 bits of byte 8 to 0b10."""
    for _ in range(10):
        var u = uuid7()
        assert_equal(Int(u.bytes[8] >> 6), 2, "byte8 high 2 bits == 0b10")


# =============================================================================
# Timestamp extraction
# =============================================================================


def test_uuid7_extract_ms_nonzero() raises:
    """Returns a positive (non-zero) timestamp."""
    var u = uuid7()
    var ms = uuid7_extract_ms(u)
    assert_true(ms > 0, "timestamp must be > 0")


def test_uuid7_extract_ms_reasonable() raises:
    """Returns a timestamp > year-2020 epoch in ms."""
    # 2020-01-01T00:00:00Z in Unix ms = 1577836800000
    var u = uuid7()
    var ms = uuid7_extract_ms(u)
    assert_true(ms > 1577836800000, "timestamp must be after year 2020")


def test_uuid7_extract_ms_consistent() raises:
    """Round-trips: bytes 0-5 encode the stored timestamp."""
    var u = uuid7()
    var ms = uuid7_extract_ms(u)
    # Re-extract manually from raw bytes and compare.
    var ms2: UInt64 = 0
    ms2 = ms2 | (UInt64(u.bytes[0]) << 40)
    ms2 = ms2 | (UInt64(u.bytes[1]) << 32)
    ms2 = ms2 | (UInt64(u.bytes[2]) << 24)
    ms2 = ms2 | (UInt64(u.bytes[3]) << 16)
    ms2 = ms2 | (UInt64(u.bytes[4]) << 8)
    ms2 = ms2 | UInt64(u.bytes[5])
    assert_equal(ms, ms2, "extracted ms must match manual reconstruction")


# =============================================================================
# Ordering property
# =============================================================================


def test_uuid7_monotonic_string_order() raises:
    """V7Generator produces strictly increasing UUID strings.

    Because v7 encodes the millisecond timestamp in the most significant
    bytes and V7Generator increments rand_a within the same millisecond,
    lexicographic string order equals time order for all generated UUIDs.
    """
    var gen = V7Generator()
    var prev = String(gen.generate())
    for _ in range(20):
        var curr = String(gen.generate())
        # The string representation sorts correctly because the timestamp
        # occupies the first 12 hex characters (48 bits).
        assert_true(
            curr >= prev,
            "V7Generator strings must be non-decreasing: "
            + prev
            + " > "
            + curr,
        )
        prev = curr


def test_uuid7_monotonic_timestamp() raises:
    """V7Generator produces non-decreasing embedded timestamps."""
    var gen = V7Generator()
    var prev_ms = uuid7_extract_ms(gen.generate())
    for _ in range(20):
        var curr_ms = uuid7_extract_ms(gen.generate())
        assert_true(
            curr_ms >= prev_ms,
            "V7Generator timestamps must be non-decreasing",
        )
        prev_ms = curr_ms


# =============================================================================
# Format compliance
# =============================================================================


def test_uuid7_string_length() raises:
    """String(uuid7()) produces a 36-character string."""
    var u = uuid7()
    assert_equal(len(String(u)), 36, "UUID string must be 36 chars")


def test_uuid7_version_char_in_string() raises:
    """String(uuid7()) has '7' at position 14 (the version digit)."""
    var u = uuid7()
    var s = String(u)
    assert_equal(s.as_bytes()[14], UInt8(ord("7")), "version digit at pos 14")


def test_uuid7_parse_roundtrip() raises:
    """UUID.parse(String(uuid7())) produces an equal UUID."""
    var u = uuid7()
    var s = String(u)
    var parsed = UUID.parse(s)
    assert_true(u == parsed, "parse(str(u)) must equal original")


def test_uuid7_not_nil() raises:
    """Never produces the nil UUID."""
    for _ in range(10):
        assert_false(uuid7().is_nil(), "uuid7() must not be nil")


# =============================================================================
# Entry point
# =============================================================================


def main() raises:
    print("=" * 60)
    print("uuid :: test_v7")
    print("=" * 60)
    TestSuite.discover_tests[__functions_in_module()]().run()
