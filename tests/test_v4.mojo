"""Tests for UUID v4 (random) generation."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from uuid.core import UUID
from uuid.v4 import uuid4, uuid4_batch

# =============================================================================
# Version and variant bits
# =============================================================================


def test_uuid4_version() raises:
    """uuid4() always produces a UUID with version == 4."""
    for _ in range(10):
        var u = uuid4()
        assert_equal(u.version(), 4, "version must be 4")


def test_uuid4_variant() raises:
    """uuid4() always produces a UUID with RFC 9562 variant (2 = 0b10)."""
    for _ in range(10):
        var u = uuid4()
        assert_equal(u.variant(), 2, "variant must be 2 (RFC 9562)")


def test_uuid4_byte6_high_nibble() raises:
    """uuid4() sets the high nibble of byte 6 to 0x4."""
    for _ in range(10):
        var u = uuid4()
        assert_equal(Int(u.bytes[6] >> 4), 4, "byte6 high nibble == 4")


def test_uuid4_byte8_high_bits() raises:
    """uuid4() sets the high 2 bits of byte 8 to 0b10."""
    for _ in range(10):
        var u = uuid4()
        assert_equal(Int(u.bytes[8] >> 6), 2, "byte8 high 2 bits == 0b10")


# =============================================================================
# Format compliance
# =============================================================================


def test_uuid4_string_length() raises:
    """String(uuid4()) produces a 36-character string."""
    var u = uuid4()
    assert_equal(len(String(u)), 36, "UUID string must be 36 chars")


def test_uuid4_string_dash_positions() raises:
    """String(uuid4()) has dashes at positions 8, 13, 18, 23."""
    var u = uuid4()
    var s = String(u)
    var b = s.as_bytes()
    assert_equal(Int(b[8]), 45, "dash at pos 8")
    assert_equal(Int(b[13]), 45, "dash at pos 13")
    assert_equal(Int(b[18]), 45, "dash at pos 18")
    assert_equal(Int(b[23]), 45, "dash at pos 23")


def test_uuid4_version_char_in_string() raises:
    """String(uuid4()) has '4' at position 14 (the version digit)."""
    var u = uuid4()
    var s = String(u)
    assert_equal(s.as_bytes()[14], UInt8(ord("4")), "version digit at pos 14")


def test_uuid4_variant_char_in_string() raises:
    """String(uuid4()) has '8', '9', 'a', or 'b' at position 19."""
    var u = uuid4()
    var s = String(u)
    var c = s.as_bytes()[19]
    # RFC 9562 variant: high 2 bits = 10 -> first hex char is 8,9,a,b
    var valid = (c == 56) or (c == 57) or (c == 97) or (c == 98)  # '8','9','a','b'
    assert_true(valid, "variant char at pos 19 must be 8, 9, a, or b")


def test_uuid4_parse_roundtrip() raises:
    """UUID.parse(String(uuid4())) produces an equal UUID."""
    var u = uuid4()
    var s = String(u)
    var parsed = UUID.parse(s)
    assert_true(u == parsed, "parse(str(u)) must equal original")


# =============================================================================
# Uniqueness
# =============================================================================


def test_uuid4_uniqueness_small() raises:
    """Ten successive uuid4() calls all produce distinct values."""
    var seen = List[String]()
    for _ in range(10):
        var s = String(uuid4())
        for prev in seen:
            assert_false(s == prev[], "uuid4() collision detected")
        seen.append(s)


def test_uuid4_not_nil() raises:
    """uuid4() never produces the nil UUID."""
    for _ in range(10):
        assert_false(uuid4().is_nil(), "uuid4() must not be nil")


# =============================================================================
# Batch generation
# =============================================================================


def test_uuid4_batch_count() raises:
    """uuid4_batch[N]() returns exactly N UUIDs."""
    var batch = uuid4_batch[5]()
    # Verify all 5 are distinct.
    for i in range(5):
        for j in range(i + 1, 5):
            assert_false(
                batch[i] == batch[j],
                "batch[" + String(i) + "] and batch[" + String(j) + "] collide",
            )


def test_uuid4_batch_version() raises:
    """All UUIDs in uuid4_batch have version == 4."""
    var batch = uuid4_batch[8]()
    for i in range(8):
        assert_equal(batch[i].version(), 4, "batch[" + String(i) + "] version")


# =============================================================================
# Entry point
# =============================================================================


def main() raises:
    print("=" * 60)
    print("uuid :: test_v4")
    print("=" * 60)
    TestSuite.discover_tests[__functions_in_module()]().run()
