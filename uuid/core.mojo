"""Core UUID struct with SIMD-backed storage and RFC 9562 operations.

Provides the `UUID` type storing all 16 bytes in a single
`SIMD[DType.uint8, 16]` register. String formatting uses vectorized hex
encoding from `simd_hex`, and parsing validates structure and hex characters.

The standard UUID string format (RFC 9562) is:

    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

where each `x` is a lowercase hex digit, and dashes appear at byte
positions 4, 6, 8, and 10.

Example:

    var u = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    print(u.version())  # 4
    print(u)            # 550e8400-e29b-41d4-a716-446655440000
    print(u == UUID.nil())  # False
"""

from uuid.simd_hex import hex_encode_16, hex_decode_32


struct UUID(Copyable, Movable, Writable, Hashable):
    """A Universally Unique Identifier (UUID) per RFC 9562.

    Stores 128 bits (16 bytes) in a single SIMD register for efficient
    vectorized operations. Supports UUID versions 4 (random) and 7
    (time-ordered), as well as the nil UUID (all zeros).

    The canonical string representation is lowercase hex with dashes:

        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

    Example:

        var u = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
        var s = String(u)   # "550e8400-e29b-41d4-a716-446655440000"
        var h = u.to_hex()  # "550e8400e29b41d4a716446655440000"
    """

    var bytes: SIMD[DType.uint8, 16]
    """The 16 raw bytes of the UUID in big-endian byte order."""

    @always_inline
    def __init__(out self, bytes: SIMD[DType.uint8, 16]):
        """Construct a UUID from 16 raw bytes.

        Args:
            bytes: The 16 bytes of the UUID in big-endian order. The caller
                is responsible for setting correct version and variant bits.
        """
        self.bytes = bytes

    @staticmethod
    def nil() -> UUID:
        """Return the nil UUID (all 128 bits set to zero).

        The nil UUID is defined by RFC 9562 as a special-form UUID with all
        bits set to zero: `00000000-0000-0000-0000-000000000000`.

        Returns:
            A UUID with all bytes set to 0.

        Example:

            var n = UUID.nil()
            print(n.is_nil())  # True
        """
        return UUID(SIMD[DType.uint8, 16](0))

    @staticmethod
    def parse(s: String) raises -> UUID:
        """Parse a UUID from its canonical string representation.

        Accepts the standard dashed format:
        `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (36 characters), where each
        `x` is a lowercase or uppercase hex digit. Dashes must appear at
        positions 8, 13, 18, and 23.

        Args:
            s: The UUID string to parse. Must be exactly 36 characters with
                dashes at the correct positions.

        Returns:
            The parsed UUID.

        Raises:
            Error: If the string length is not 36, if dashes are missing or
                misplaced, or if any hex character is invalid.

        Example:

            var u = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
            var u2 = UUID.parse("550E8400-E29B-41D4-A716-446655440000")  # uppercase ok
        """
        var b = s.as_bytes()
        if len(b) != 36:
            raise Error(
                "UUID string must be 36 characters, got " + String(len(b))
            )
        # Validate dash positions.
        if b[8] != 45 or b[13] != 45 or b[18] != 45 or b[23] != 45:
            raise Error(
                "UUID string must have dashes at positions 8, 13, 18, 23"
            )
        # Build a contiguous 32-hex-char buffer by stripping the 4 dashes.
        var hex32 = InlineArray[UInt8, 32](uninitialized=True)
        # Segment 0: s[0..7]  -> hex32[0..7]  (8 chars)
        for j in range(8):
            hex32[j] = b[j]
        # Segment 1: s[9..12] -> hex32[8..11] (4 chars)
        for j in range(4):
            hex32[8 + j] = b[9 + j]
        # Segment 2: s[14..17] -> hex32[12..15] (4 chars)
        for j in range(4):
            hex32[12 + j] = b[14 + j]
        # Segment 3: s[19..22] -> hex32[16..19] (4 chars)
        for j in range(4):
            hex32[16 + j] = b[19 + j]
        # Segment 4: s[24..35] -> hex32[20..31] (12 chars)
        for j in range(12):
            hex32[20 + j] = b[24 + j]
        return UUID(hex_decode_32(Span(hex32)))

    def to_hex(self) -> String:
        """Return the UUID as a 32-character lowercase hex string without dashes.

        Returns:
            A 32-character lowercase hex string (no dashes).

        Example:

            var u = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
            print(u.to_hex())  # "550e8400e29b41d4a716446655440000"
        """
        var encoded = hex_encode_16(self.bytes)
        var result = String(capacity=32)
        for i in range(32):
            result += chr(Int(encoded[i]))
        return result

    def write_to[W: Writer](self, mut writer: W):
        """Write the canonical UUID string to a writer.

        Writes the 36-character dashed format:
        `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.

        Parameters:
            W: A type implementing the `Writer` trait.

        Args:
            writer: The writer to write the UUID string to.
        """
        var encoded = hex_encode_16(self.bytes)
        # Segments end at hex positions: 8, 12, 16, 20, 32
        # with dashes between segments.
        var pos = 0
        for _ in range(8):
            writer.write(chr(Int(encoded[pos])))
            pos += 1
        writer.write("-")
        for _ in range(4):
            writer.write(chr(Int(encoded[pos])))
            pos += 1
        writer.write("-")
        for _ in range(4):
            writer.write(chr(Int(encoded[pos])))
            pos += 1
        writer.write("-")
        for _ in range(4):
            writer.write(chr(Int(encoded[pos])))
            pos += 1
        writer.write("-")
        for _ in range(12):
            writer.write(chr(Int(encoded[pos])))
            pos += 1

    def __str__(self) -> String:
        """Return the canonical 36-character dashed UUID string.

        Returns:
            The UUID in the format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.

        Example:

            var u = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
            print(String(u))  # "550e8400-e29b-41d4-a716-446655440000"
        """
        return String.write(self)

    @always_inline
    def version(self) -> Int:
        """Return the UUID version number (bits 76-79 of byte 6).

        Per RFC 9562, the version field occupies the high 4 bits of byte 6.
        Common values: 4 (random), 7 (time-ordered).

        Returns:
            The version number as an integer (1-8 for standard UUIDs, 0 for nil).

        Example:

            var u = uuid4()
            print(u.version())  # 4
        """
        return Int(self.bytes[6] >> 4)

    @always_inline
    def variant(self) -> Int:
        """Return the UUID variant field value (high bits of byte 8).

        Per RFC 9562, the variant occupies the high 2 bits of byte 8:
        - `0b10` (2): RFC 9562 / RFC 4122 variant (standard).
        - `0b11` (3): Microsoft reserved.
        - `0b0x` (0 or 1): NCS backward compatibility.

        Returns:
            The variant value as an integer (0-3).

        Example:

            var u = uuid4()
            print(u.variant())  # 2
        """
        return Int(self.bytes[8] >> 6)

    @always_inline
    def is_nil(self) -> Bool:
        """Return True if all 128 bits are zero (nil UUID).

        Returns:
            True if the UUID equals `00000000-0000-0000-0000-000000000000`.

        Example:

            var n = UUID.nil()
            print(n.is_nil())   # True
            print(uuid4().is_nil())  # False
        """
        for i in range(16):
            if self.bytes[i] != 0:
                return False
        return True

    @always_inline
    def __eq__(self, other: UUID) -> Bool:
        """Return True if both UUIDs represent the same 128-bit value.

        Args:
            other: The UUID to compare against.

        Returns:
            True if all 16 bytes are equal.
        """
        for i in range(16):
            if self.bytes[i] != other.bytes[i]:
                return False
        return True

    @always_inline
    def __ne__(self, other: UUID) -> Bool:
        """Return True if the UUIDs represent different 128-bit values.

        Args:
            other: The UUID to compare against.

        Returns:
            True if any byte differs.
        """
        return not self.__eq__(other)

    def __hash__(self) -> UInt:
        """Return a hash of the UUID suitable for use in hash-based collections.

        Uses a FNV-1a-inspired mix over the 16 UUID bytes for good
        distribution with low collision probability.

        Returns:
            An unsigned integer hash value.
        """
        var h: UInt = 14695981039346656037
        for i in range(16):
            h = h ^ UInt(self.bytes[i])
            h = h * 1099511628211
        return h

    def to_bytes(self) -> InlineArray[UInt8, 16]:
        """Return the 16 UUID bytes as a fixed-size inline array.

        Bytes are in big-endian (network) order per RFC 9562.

        Returns:
            An `InlineArray[UInt8, 16]` containing the raw UUID bytes.

        Example:

            var u = uuid4()
            var b = u.to_bytes()
            # b[6] >> 4 == 4  (version bits)
        """
        var result = InlineArray[UInt8, 16](uninitialized=True)
        for i in range(16):
            result[i] = self.bytes[i]
        return result
