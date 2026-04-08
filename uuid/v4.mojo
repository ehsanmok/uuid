"""UUID version 4 (random) generation per RFC 9562.

UUID v4 fills all 128 bits with cryptographically random data, then sets
the version and variant fields to comply with RFC 9562:

    - Bits 76-79 (high nibble of byte 6) = 0100 (version 4)
    - Bits 62-63 (high 2 bits of byte 8) = 10   (RFC 4122/9562 variant)

Two calls to `random_ui64()` provide 128 random bits for the full UUID,
and the version/variant bits are applied with bitwise operations directly
on the SIMD register.

Example:

    from uuid import uuid4

    var id = uuid4()
    print(id)            # e.g. "a8098c1a-f86e-11da-bd1a-00112444be1e"
    print(id.version())  # 4
    print(id.variant())  # 2
"""

from random import random_ui64
from uuid.core import UUID


@always_inline
def uuid4() -> UUID:
    """Generate a random UUID version 4 per RFC 9562.

    Fills 128 bits with random data using two `random_ui64()` calls, then
    sets the version field to `4` and the variant field to the RFC 9562
    value (`0b10`).

    Returns:
        A new UUID with version=4 and variant=2 (RFC 9562).

    Example:

        var id = uuid4()
        print(id.version())  # 4
        print(id.variant())  # 2
        print(id)            # "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    """
    var hi = random_ui64(0, UInt64.MAX)
    var lo = random_ui64(0, UInt64.MAX)

    # Unpack hi (bytes 0-7) and lo (bytes 8-15) into a SIMD vector.
    var b = SIMD[DType.uint8, 16]()
    for i in range(8):
        b[i] = UInt8((hi >> UInt64(56 - i * 8)) & 0xFF)
        b[i + 8] = UInt8((lo >> UInt64(56 - i * 8)) & 0xFF)

    # Set version: high nibble of byte 6 = 0100 (version 4).
    b[6] = (b[6] & 0x0F) | 0x40
    # Set variant: high 2 bits of byte 8 = 10 (RFC 9562 variant).
    b[8] = (b[8] & 0x3F) | 0x80

    return UUID(b)


def uuid4_batch[N: Int]() -> InlineArray[UUID, N]:
    """Generate `N` random UUID v4 values in a single call.

    Amortizes the function call overhead across `N` UUIDs. Useful when
    many UUIDs are needed at once (e.g. bulk record creation).

    Parameters:
        N: The number of UUIDs to generate. Must be a positive compile-time
            constant.

    Returns:
        An `InlineArray[UUID, N]` with `N` independently random v4 UUIDs.

    Example:

        var ids = uuid4_batch[100]()
        for i in range(100):
            print(ids[i])
    """
    var result = InlineArray[UUID, N](uninitialized=True)
    for i in range(N):
        result[i] = uuid4()
    return result^
