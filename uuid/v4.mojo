"""UUID version 4 (random) generation per RFC 9562.

UUID v4 fills all 128 bits with cryptographically random data, then sets
the version and variant fields to comply with RFC 9562:

    - Bits 76-79 (high nibble of byte 6) = 0100 (version 4)
    - Bits 62-63 (high 2 bits of byte 8) = 10   (RFC 4122/9562 variant)

Entropy is obtained directly from the OS via `/dev/urandom` (POSIX), which
provides cryptographically strong randomness. This avoids the deterministic
output of `std.random`'s PRNG when its global state is unseeded (seed = 0).

Example:

    from uuid import uuid4

    var id = uuid4()
    print(id)            # e.g. "a8098c1a-f86e-11da-bd1a-00112444be1e"
    print(id.version())  # 4
    print(id.variant())  # 2
"""

from std.collections import InlineArray
from std.ffi import external_call
from uuid.core import UUID


@always_inline
def uuid4() raises -> UUID:
    """Generate a random UUID version 4 per RFC 9562.

    Reads 16 bytes of OS entropy from `/dev/urandom`, then sets the version
    field to `4` and the variant field to the RFC 9562 value (`0b10`).

    Unlike `random_ui64()`, `/dev/urandom` is seeded by the OS at boot and is
    safe to call immediately without explicit seeding. This guarantees unique
    output across process restarts, forks, and concurrent callers.

    Returns:
        A new UUID with version=4 and variant=2 (RFC 9562).

    Raises:
        Error: If entropy cannot be read from `/dev/urandom`.

    Example:

        var id = uuid4()
        print(id.version())  # 4
        print(id.variant())  # 2
        print(id)            # "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    """
    var buf = InlineArray[UInt8, 16](fill=0)

    # Read 16 bytes of OS entropy. O_RDONLY = 0 on macOS and Linux.
    var path = String("/dev/urandom")
    var fd = external_call["open", Int32](path.unsafe_ptr(), Int32(0))
    if fd < 0:
        raise Error("uuid4: cannot open /dev/urandom (fd=" + String(fd) + ")")
    var nread = external_call["read", Int64](fd, buf.unsafe_ptr(), Int64(16))
    _ = external_call["close", Int32](fd)
    if nread != Int64(16):
        raise Error(
            "uuid4: short read from /dev/urandom ("
            + String(nread)
            + "/16 bytes)"
        )

    var b = SIMD[DType.uint8, 16]()
    for i in range(16):
        b[i] = buf[i]

    # Set version: high nibble of byte 6 = 0100 (version 4).
    b[6] = (b[6] & 0x0F) | 0x40
    # Set variant: high 2 bits of byte 8 = 10 (RFC 9562 variant).
    b[8] = (b[8] & 0x3F) | 0x80

    return UUID(b)


def uuid4_batch[N: Int]() raises -> InlineArray[UUID, N]:
    """Generate `N` random UUID v4 values in a single call.

    Each UUID is independently generated from OS entropy. Useful when many
    UUIDs are needed at once (e.g. bulk record creation).

    Parameters:
        N: The number of UUIDs to generate. Must be a positive compile-time
            constant.

    Returns:
        An `InlineArray[UUID, N]` with `N` independently random v4 UUIDs.

    Raises:
        Error: If entropy cannot be read from `/dev/urandom`.

    Example:

        var ids = uuid4_batch[100]()
        for i in range(100):
            print(ids[i])
    """
    var result = InlineArray[UUID, N](uninitialized=True)
    for i in range(N):
        result[i] = uuid4()
    return result^
