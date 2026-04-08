"""Tests for the UUID core struct: parse, format, version, variant, equality, hash."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from uuid.core import UUID
from uuid.simd_hex import hex_encode_16

# Well-known test UUID string.
comptime KNOWN_STR = "550e8400-e29b-41d4-a716-446655440000"
comptime KNOWN_HEX = "550e8400e29b41d4a716446655440000"

# =============================================================================
# Parse: valid inputs
# =============================================================================


def test_parse_lowercase() raises:
    """UUID.parse accepts a lowercase dashed UUID string."""
    var u = UUID.parse(KNOWN_STR)
    assert_equal(Int(u.bytes[0]), 0x55)
    assert_equal(Int(u.bytes[1]), 0x0E)


def test_parse_uppercase() raises:
    """UUID.parse accepts an uppercase dashed UUID string."""
    var u = UUID.parse("550E8400-E29B-41D4-A716-446655440000")
    assert_equal(Int(u.bytes[0]), 0x55)
    assert_equal(Int(u.bytes[1]), 0x0E)


def test_parse_mixed_case() raises:
    """UUID.parse accepts mixed-case hex characters."""
    var u = UUID.parse("550e8400-E29B-41d4-A716-446655440000")
    assert_equal(Int(u.bytes[0]), 0x55)


def test_parse_nil_string() raises:
    """UUID.parse correctly parses the nil UUID string."""
    var u = UUID.parse("00000000-0000-0000-0000-000000000000")
    assert_true(u.is_nil(), "parsed nil UUID must be nil")


def test_parse_all_ff() raises:
    """UUID.parse correctly parses a UUID of all 0xFF bytes."""
    var u = UUID.parse("ffffffff-ffff-ffff-ffff-ffffffffffff")
    for i in range(16):
        assert_equal(Int(u.bytes[i]), 0xFF, "byte " + String(i))


def test_parse_roundtrip() raises:
    """String(UUID.parse(s)) == s for a known UUID string."""
    var u = UUID.parse(KNOWN_STR)
    assert_equal(String(u), KNOWN_STR, "roundtrip must be identical")


# =============================================================================
# Parse: invalid inputs
# =============================================================================


def test_parse_wrong_length_short() raises:
    """UUID.parse raises on a string that is too short."""
    var raised = False
    try:
        _ = UUID.parse("550e8400-e29b-41d4")
    except:
        raised = True
    assert_true(raised, "expected Error for short string")


def test_parse_wrong_length_long() raises:
    """UUID.parse raises on a string that is too long."""
    var raised = False
    try:
        _ = UUID.parse(KNOWN_STR + "0")
    except:
        raised = True
    assert_true(raised, "expected Error for long string")


def test_parse_missing_dash() raises:
    """UUID.parse raises if a dash is replaced by a hex character."""
    var raised = False
    try:
        _ = UUID.parse("550e840000e29b41d4a716446655440000")
    except:
        raised = True
    assert_true(raised, "expected Error for missing dash")


def test_parse_invalid_hex_char() raises:
    """UUID.parse raises if any hex character is invalid."""
    var raised = False
    try:
        _ = UUID.parse("550e8400-e29b-41d4-a716-44665544gggg")
    except:
        raised = True
    assert_true(raised, "expected Error for invalid hex char")


# =============================================================================
# Formatting
# =============================================================================


def test_str_format() raises:
    """String(u) returns the 36-character dashed UUID string."""
    var u = UUID.parse(KNOWN_STR)
    var s = String(u)
    assert_equal(len(s), 36, "formatted string must be 36 chars")
    assert_equal(s, KNOWN_STR)


def test_str_dash_positions() raises:
    """String(u) has dashes at positions 8, 13, 18, 23."""
    var u = UUID.parse(KNOWN_STR)
    var s = String(u)
    var b = s.as_bytes()
    assert_equal(Int(b[8]), 45, "dash at pos 8")
    assert_equal(Int(b[13]), 45, "dash at pos 13")
    assert_equal(Int(b[18]), 45, "dash at pos 18")
    assert_equal(Int(b[23]), 45, "dash at pos 23")


def test_to_hex_no_dashes() raises:
    """Returns 32 characters with no dashes."""
    var u = UUID.parse(KNOWN_STR)
    var h = u.to_hex()
    assert_equal(len(h), 32, "hex string must be 32 chars")
    assert_equal(h, KNOWN_HEX)


def test_to_hex_is_lowercase() raises:
    """Always produces lowercase hex characters."""
    var u = UUID.parse("FFFFFFFF-FFFF-4FFF-AFFF-FFFFFFFFFFFF")
    var h = u.to_hex()
    var b = h.as_bytes()
    for i in range(32):
        var c = b[i]
        # Must be 0-9 or a-f (not A-F).
        var is_digit = c >= 48 and c <= 57
        var is_lower = c >= 97 and c <= 102
        assert_true(is_digit or is_lower, "char at " + String(i) + " must be lowercase hex")


# =============================================================================
# nil UUID
# =============================================================================


def test_nil_is_nil() raises:
    """UUID.nil() returns a UUID where is_nil() is True."""
    assert_true(UUID.nil().is_nil())


def test_non_nil_is_not_nil() raises:
    """Returns False for a non-zero UUID."""
    var u = UUID.parse(KNOWN_STR)
    assert_false(u.is_nil(), "known UUID must not be nil")


def test_nil_string() raises:
    """String(UUID.nil()) is the canonical nil UUID string."""
    assert_equal(
        String(UUID.nil()),
        "00000000-0000-0000-0000-000000000000",
    )


# =============================================================================
# version / variant
# =============================================================================


def test_version_4() raises:
    """Extracts the correct version value for a v4 UUID."""
    # "41d4" -> byte 6 = 0x41 -> high nibble = 4
    var u = UUID.parse(KNOWN_STR)
    assert_equal(u.version(), 4)


def test_variant_rfc() raises:
    """Extracts the RFC 9562 variant (2 = 0b10) from byte 8."""
    # "a716" -> byte 8 = 0xa7 -> high 2 bits = 0b10 = 2
    var u = UUID.parse(KNOWN_STR)
    assert_equal(u.variant(), 2)


def test_nil_version() raises:
    """UUID.nil() has version 0."""
    assert_equal(UUID.nil().version(), 0)


# =============================================================================
# Equality
# =============================================================================


def test_equal_same_uuid() raises:
    """Two UUIDs parsed from the same string are equal."""
    var a = UUID.parse(KNOWN_STR)
    var b = UUID.parse(KNOWN_STR)
    assert_true(a == b, "same UUID must be equal")


def test_not_equal_different() raises:
    """Two different UUIDs are not equal."""
    var a = UUID.parse(KNOWN_STR)
    var b = UUID.parse("550e8400-e29b-41d4-a716-000000000000")
    assert_true(a != b, "different UUIDs must not be equal")


def test_nil_equal_nil() raises:
    """Two nil UUIDs are equal."""
    assert_true(UUID.nil() == UUID.nil())


def test_nil_not_equal_known() raises:
    """Nil UUID is not equal to a non-zero UUID."""
    assert_true(UUID.nil() != UUID.parse(KNOWN_STR))


# =============================================================================
# Hash
# =============================================================================


def test_hash_same_uuid() raises:
    """Two equal UUIDs produce the same hash."""
    var a = UUID.parse(KNOWN_STR)
    var b = UUID.parse(KNOWN_STR)
    assert_equal(hash(a), hash(b), "equal UUIDs must hash equally")


def test_hash_nil() raises:
    """UUID.nil() produces a consistent hash."""
    assert_equal(hash(UUID.nil()), hash(UUID.nil()))


def test_hash_different_likely_different() raises:
    """Two different UUIDs are unlikely to have the same hash."""
    var a = UUID.parse(KNOWN_STR)
    var b = UUID.parse("550e8400-e29b-41d4-a716-000000000001")
    # Hash collision is theoretically possible but astronomically unlikely.
    assert_false(
        hash(a) == hash(b), "different UUIDs should have different hashes"
    )


# =============================================================================
# to_bytes
# =============================================================================


def test_to_bytes_roundtrip() raises:
    """Returns the same byte values as the internal SIMD vector."""
    var u = UUID.parse(KNOWN_STR)
    var b = u.to_bytes()
    for i in range(16):
        assert_equal(Int(b[i]), Int(u.bytes[i]), "byte " + String(i))


def test_to_bytes_nil() raises:
    """Returns all zeros for the nil UUID."""
    var n = UUID.nil()
    var b = n.to_bytes()
    for i in range(16):
        assert_equal(Int(b[i]), 0, "byte " + String(i))


# =============================================================================
# Entry point
# =============================================================================


def main() raises:
    print("=" * 60)
    print("uuid :: test_core")
    print("=" * 60)
    TestSuite.discover_tests[__functions_in_module()]().run()
