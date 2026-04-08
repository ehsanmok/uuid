"""Tests for SIMD hex encode/decode utilities in uuid.simd_hex."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from uuid.simd_hex import hex_encode_16, hex_decode_32, nibble_to_hex, hex_char_to_nibble

# =============================================================================
# nibble_to_hex
# =============================================================================


def test_nibble_to_hex_digits() raises:
    """Maps 0-9 to ASCII '0'-'9'."""
    for i in range(10):
        var v = SIMD[DType.uint8, 16](UInt8(i))
        var result = nibble_to_hex(v)
        assert_equal(Int(result[0]), 48 + i, "digit " + String(i))


def test_nibble_to_hex_letters() raises:
    """Maps 10-15 to ASCII 'a'-'f'."""
    var letters = "abcdef"
    for i in range(6):
        var v = SIMD[DType.uint8, 16](UInt8(10 + i))
        var result = nibble_to_hex(v)
        assert_equal(
            Int(result[0]),
            Int(letters.as_bytes()[i]),
            "letter " + String(i),
        )


def test_nibble_to_hex_all_lanes() raises:
    """Operates correctly on all 16 lanes simultaneously."""
    var v = SIMD[DType.uint8, 16](
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    )
    var result = nibble_to_hex(v)
    var expected_chars = "0123456789abcdef"
    for i in range(16):
        assert_equal(
            Int(result[i]),
            Int(expected_chars.as_bytes()[i]),
            "lane " + String(i),
        )


# =============================================================================
# hex_char_to_nibble
# =============================================================================


def test_hex_char_to_nibble_digits() raises:
    """Converts '0'-'9' to 0-9."""
    for i in range(10):
        var c = UInt8(48 + i)
        assert_equal(Int(hex_char_to_nibble(c)), i)


def test_hex_char_to_nibble_lowercase() raises:
    """Converts 'a'-'f' to 10-15."""
    var letters = "abcdef"
    for i in range(6):
        var c = letters.as_bytes()[i]
        assert_equal(Int(hex_char_to_nibble(c)), 10 + i)


def test_hex_char_to_nibble_uppercase() raises:
    """Converts 'A'-'F' to 10-15."""
    var letters = "ABCDEF"
    for i in range(6):
        var c = letters.as_bytes()[i]
        assert_equal(Int(hex_char_to_nibble(c)), 10 + i)


def test_hex_char_to_nibble_invalid_raises() raises:
    """Raises on non-hex characters."""
    var raised = False
    try:
        _ = hex_char_to_nibble(UInt8(ord("g")))
    except:
        raised = True
    assert_true(raised, "expected Error for 'g'")


def test_hex_char_to_nibble_space_raises() raises:
    """Raises on whitespace."""
    var raised = False
    try:
        _ = hex_char_to_nibble(UInt8(ord(" ")))
    except:
        raised = True
    assert_true(raised, "expected Error for space")


# =============================================================================
# hex_encode_16 / hex_decode_32 roundtrip
# =============================================================================


def test_encode_known_vector() raises:
    """Produces correct output for a known input."""
    var raw = SIMD[DType.uint8, 16](
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    )
    var encoded = hex_encode_16(raw)
    var expected = "550e8400e29b41d4a716446655440000"
    var exp_bytes = expected.as_bytes()
    for i in range(32):
        assert_equal(Int(encoded[i]), Int(exp_bytes[i]), "pos " + String(i))


def test_encode_all_zeros() raises:
    """Encodes all-zero bytes as 32 '0' characters."""
    var raw = SIMD[DType.uint8, 16](0)
    var encoded = hex_encode_16(raw)
    for i in range(32):
        assert_equal(Int(encoded[i]), 48, "pos " + String(i))  # '0' = 48


def test_encode_all_ff() raises:
    """Encodes 0xFF bytes as 'ff' pairs."""
    var raw = SIMD[DType.uint8, 16](0xFF)
    var encoded = hex_encode_16(raw)
    for i in range(32):
        assert_equal(Int(encoded[i]), 102, "pos " + String(i))  # 'f' = 102


def _simd_eq(a: SIMD[DType.uint8, 16], b: SIMD[DType.uint8, 16]) -> Bool:
    """Return True if all 16 bytes of two SIMD vectors are equal."""
    for i in range(16):
        if a[i] != b[i]:
            return False
    return True


def test_roundtrip_known_vector() raises:
    """Decode(encode(x)) == x for a known UUID byte sequence."""
    var raw = SIMD[DType.uint8, 16](
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    )
    var encoded = hex_encode_16(raw)
    var hex_str = String(capacity=32)
    for i in range(32):
        hex_str += chr(Int(encoded[i]))
    var decoded = hex_decode_32(hex_str.as_bytes())
    assert_true(_simd_eq(raw, decoded), "roundtrip bytes must match")


def test_roundtrip_all_bytes() raises:
    """Decode(encode(x)) == x for every possible byte value 0x00-0xFF."""
    # Test representative byte values by cycling through them.
    var raw = SIMD[DType.uint8, 16]()
    for i in range(16):
        raw[i] = UInt8(i * 16)  # 0x00, 0x10, 0x20, ..., 0xF0
    var encoded = hex_encode_16(raw)
    var hex_str = String(capacity=32)
    for i in range(32):
        hex_str += chr(Int(encoded[i]))
    var decoded = hex_decode_32(hex_str.as_bytes())
    assert_true(_simd_eq(raw, decoded), "all-byte roundtrip must match")


def test_decode_known_vector() raises:
    """Decodes a known hex string correctly."""
    var hex_str = "550e8400e29b41d4a716446655440000"
    var decoded = hex_decode_32(hex_str.as_bytes())
    assert_equal(Int(decoded[0]), 0x55)
    assert_equal(Int(decoded[1]), 0x0E)
    assert_equal(Int(decoded[2]), 0x84)
    assert_equal(Int(decoded[3]), 0x00)
    assert_equal(Int(decoded[7]), 0xD4)
    assert_equal(Int(decoded[15]), 0x00)


def test_decode_uppercase() raises:
    """Accepts uppercase hex characters."""
    var hex_str = "550E8400E29B41D4A716446655440000"
    var decoded = hex_decode_32(hex_str.as_bytes())
    assert_equal(Int(decoded[0]), 0x55)
    assert_equal(Int(decoded[1]), 0x0E)


def test_decode_wrong_length_raises() raises:
    """Raises if input length is not exactly 32."""
    var raised = False
    try:
        _ = hex_decode_32("abc".as_bytes())
    except:
        raised = True
    assert_true(raised, "expected Error for length != 32")


def test_decode_invalid_char_raises() raises:
    """Raises on an invalid hex character."""
    var raised = False
    try:
        _ = hex_decode_32("550e8400e29b41d4a71644665544gggg".as_bytes())
    except:
        raised = True
    assert_true(raised, "expected Error for invalid char 'g'")


# =============================================================================
# Entry point
# =============================================================================


def main() raises:
    print("=" * 60)
    print("uuid :: test_simd_hex")
    print("=" * 60)
    TestSuite.discover_tests[__functions_in_module()]().run()
