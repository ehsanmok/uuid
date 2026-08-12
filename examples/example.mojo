"""Practical usage examples for the uuid library.

Demonstrates UUID v4 (random) and v7 (time-ordered) generation, string
parsing, hex formatting, comparison, nil UUID detection, and batch generation.

Run with:

    mojo -I . examples/example.mojo

or via pixi:

    pixi run example
"""

from uuid import UUID, uuid4, uuid4_batch, uuid7, uuid7_extract_ms


def section(name: String):
    print("\n--- " + name + " ---")


def demo_v4() raises:
    section("UUID v4 (random)")

    var id4 = uuid4()
    print("Generated:  ", id4)
    print("Version:    ", id4.version())  # 4
    print("Variant:    ", id4.variant())  # 2 (RFC 9562)
    print("Is nil:     ", id4.is_nil())  # False


def demo_v7() raises:
    section("UUID v7 (time-ordered)")

    var id7a = uuid7()
    var id7b = uuid7()
    print("v7 first:   ", id7a)
    print("v7 second:  ", id7b)
    print("Version:    ", id7a.version())  # 7
    print("Timestamp (ms):", uuid7_extract_ms(id7a))

    # v7 UUIDs are lexicographically (and thus time) ordered.
    var sa = String(id7a)
    var sb = String(id7b)
    print("Time-ordered: first <= second:", sa <= sb)  # True


def demo_parsing() raises:
    section("Parsing from string")

    var known = "550e8400-e29b-41d4-a716-446655440000"
    var parsed = UUID.parse(known)
    print("Parsed:     ", parsed)
    print("Version:    ", parsed.version())  # 4
    print("Variant:    ", parsed.variant())  # 2
    print("Roundtrip OK:", String(parsed) == known)  # True

    # Uppercase input is also accepted.
    var upper = UUID.parse("550E8400-E29B-41D4-A716-446655440000")
    print("Upper parse OK:", String(upper) == known)  # True

    # Parsing an invalid string raises an error.
    print("Attempting to parse invalid UUID...")
    try:
        _ = UUID.parse("not-a-uuid")
    except e:
        print("Parse error (expected):", e)


def demo_hex() raises:
    section("Hex formatting (no dashes)")

    var parsed = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    var hex_str = parsed.to_hex()
    print("Hex (no dashes):", hex_str)
    print("Length:", hex_str.byte_length())  # 32


def demo_equality() raises:
    section("Equality comparison")

    var a = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    var b = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    var c = uuid4()
    print("a == b:", a == b)  # True
    print("a != c:", a != c)  # True (almost certainly)


def demo_nil() raises:
    section("Nil UUID")

    var nil_uuid = UUID.nil()
    print("Nil UUID:   ", nil_uuid)
    print("Is nil:     ", nil_uuid.is_nil())  # True
    print("Non-nil is_nil:", uuid4().is_nil())  # False


def demo_raw_bytes() raises:
    section("Raw bytes access")

    var u = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    # Access individual bytes via the underlying SIMD vector.
    print("bytes[0] =", Int(u.bytes[0]))  # 85 (0x55)
    print("bytes[1] =", Int(u.bytes[1]))  # 14 (0x0e)
    print("hex string =", u.to_hex())  # "550e8400e29b41d4a716446655440000"


def demo_batch() raises:
    section("Batch generation (5 v4 UUIDs)")

    var batch = uuid4_batch[5]()
    for i in range(5):
        print("  [" + String(i) + "]", batch[i])


def demo_hash() raises:
    section("Hash")

    var a = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    var b = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
    var c = uuid4()
    var h1 = hash(a)
    var h2 = hash(b)
    var h3 = hash(c)
    print("hash(a) == hash(b):", h1 == h2)  # True (same UUID)
    print("hash(a) == hash(c):", h1 == h3)  # False (different UUID)


def main() raises:
    print("=" * 60)
    print("uuid library examples")
    print("=" * 60)

    demo_v4()
    demo_v7()
    demo_parsing()
    demo_hex()
    demo_equality()
    demo_nil()
    demo_raw_bytes()
    demo_batch()
    demo_hash()

    print("\n" + "=" * 60)
    print("All examples completed successfully.")
    print("=" * 60)
