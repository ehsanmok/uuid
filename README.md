# uuid

[![CI](https://github.com/ehsanmok/uuid/actions/workflows/ci.yml/badge.svg)](https://github.com/ehsanmok/uuid/actions)
[![Docs](https://github.com/ehsanmok/uuid/actions/workflows/docs.yaml/badge.svg)](https://ehsanmok.github.io/uuid)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Fast UUID v4 and v7 generation for Mojo with SIMD-accelerated hex encoding.

All 16 UUID bytes live in a single `SIMD[DType.uint8, 16]` register. Hex
encoding processes all bytes simultaneously using vectorized nibble arithmetic
and a compile-time interleave shuffle, inspired by
[Richard Lupton's SIMD hex encoding](https://richardlupton.com/posts/simd-hex/).

## Quick Start

```mojo
from uuid import UUID, uuid4, uuid7

# Random UUID (version 4)
var id = uuid4()
print(id)            # "a8098c1a-f86e-11da-bd1a-00112444be1e"
print(id.version())  # 4
print(id.variant())  # 2  (RFC 9562)

# Time-ordered UUID (version 7)
var id7 = uuid7()
print(id7.version())  # 7

# Parse from string
var parsed = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
print(parsed.to_hex())  # "550e8400e29b41d4a716446655440000"

# Nil UUID (all zeros)
var nil = UUID.nil()
print(nil.is_nil())  # True

# Batch generation (100 UUIDs)
var ids = uuid4_batch[100]()
```

## Installation

Add uuid to your project's `pixi.toml`:

```toml
[workspace]
channels = ["https://conda.modular.com/max-nightly", "conda-forge"]
preview = ["pixi-build"]

[dependencies]
uuid = { git = "https://github.com/ehsanmok/uuid.git", branch = "main" }
```

Then run:

```bash
pixi install
```

## API Reference

### `UUID` struct

```mojo
struct UUID(Stringable, Writable, EqualityComparable, Hashable)
```

Stores 128 bits in `SIMD[DType.uint8, 16]` for vectorized operations.

| Method / Field                  | Description                                      |
|---------------------------------|--------------------------------------------------|
| `UUID.parse(s) raises -> UUID`  | Parse from 36-char dashed string                 |
| `UUID.nil() -> UUID`            | All-zero nil UUID                                |
| `String(u)` / `write_to`        | 36-char dashed `xxxxxxxx-xxxx-xxxx-xxxx-xxxx`    |
| `u.to_hex() -> String`          | 32-char hex (no dashes)                          |
| `u.version() -> Int`            | Version field (4 or 7 for standard UUIDs)        |
| `u.variant() -> Int`            | Variant field (2 = RFC 9562)                     |
| `u.is_nil() -> Bool`            | True if all 128 bits are zero                    |
| `u == other` / `u != other`     | Equality comparison                              |
| `hash(u)`                       | Hash value for use in sets / dicts               |
| `u.to_bytes()`                  | `InlineArray[UInt8, 16]` of raw bytes            |
| `u.bytes`                       | Direct `SIMD[DType.uint8, 16]` field             |

### Generation functions

```mojo
from uuid import uuid4, uuid4_batch, uuid7, uuid7_extract_ms
```

| Function                   | Description                                     |
|----------------------------|-------------------------------------------------|
| `uuid4() -> UUID`          | Random UUID v4 (RFC 9562)                       |
| `uuid4_batch[N]() -> ...`  | N random v4 UUIDs as `InlineArray[UUID, N]`     |
| `uuid7() -> UUID`          | Time-ordered v7 UUID with monotonicity          |
| `uuid7_extract_ms(u)`      | Extract Unix ms timestamp from a v7 UUID        |

### SIMD hex primitives (low-level)

```mojo
from uuid.simd_hex import hex_encode_16, hex_decode_32, nibble_to_hex
```

| Function                                  | Description                              |
|-------------------------------------------|------------------------------------------|
| `nibble_to_hex(SIMD[u8,16]) -> SIMD[u8,16]` | Map 0-15 to ASCII '0'-'9','a'-'f'    |
| `hex_encode_16(SIMD[u8,16]) -> SIMD[u8,32]` | Encode 16 bytes to 32 hex chars       |
| `hex_decode_32(Span[UInt8]) raises -> ...`   | Decode 32 hex chars to 16 bytes       |

## UUID Versions

### UUID v4 (random)

All 128 bits are random with two reserved fields:

```
xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
              ^    ^
              |    +-- y: variant bits (8, 9, a, or b)
              +------- 4: version digit
```

Bit layout per RFC 9562:

```
 0               16              32              48
 random_a (32)    random_b (16)  ver(4) rand_c   var(2) random_d ...
```

### UUID v7 (time-ordered)

Embeds a 48-bit Unix millisecond timestamp for natural sort order:

```
tttttttt-tttt-7xxx-yxxx-xxxxxxxxxxxx
^             ^    ^
|             |    +-- y: variant bits
|             +------- 7: version digit
+--- Unix ms timestamp (48 bits, big-endian)
```

Bit layout per RFC 9562:

```
 0         48   52   64   66         128
 unix_ts_ms ver rand_a var  rand_b
```

`uuid7()` guarantees that if two calls occur in the same millisecond,
the `rand_a` counter is incremented to ensure strict ordering.

### Nil UUID

`UUID.nil()` is the special-form UUID with all 128 bits set to zero:
`00000000-0000-0000-0000-000000000000`.

## UUID v4 vs v7: When to Use Which

| Property               | v4 (random)    | v7 (time-ordered)         |
|------------------------|----------------|---------------------------|
| Uniqueness             | Random         | Timestamp + random        |
| Sort order             | Random         | Chronological             |
| Database index locality| Poor           | Excellent                 |
| Predictability         | None           | Timestamp is predictable  |
| Use case               | General IDs    | Primary keys, audit logs  |

## Performance

Operations use `SIMD[DType.uint8, 16]` throughout. Approximate throughput
on an Apple M-series chip:

| Operation           | Approx. Time |
|---------------------|--------------|
| `uuid4()` generate  | < 100 ns     |
| `uuid7()` generate  | < 150 ns     |
| `UUID.parse()`      | < 80 ns      |
| `String(UUID)`      | < 50 ns      |
| `uuid4_batch[100]`  | < 5 µs       |

Run benchmarks:

```bash
pixi run bench
```

## Comparison to Python's `uuid` module

| Feature                | Python `uuid`    | Mojo `uuid`         |
|------------------------|------------------|---------------------|
| UUID v4                | `uuid.uuid4()`   | `uuid4()`           |
| UUID v7                | Python 3.13+     | `uuid7()`           |
| Parse string           | `uuid.UUID(s)`   | `UUID.parse(s)`     |
| Format string          | `str(u)`         | `String(u)`         |
| Hex (no dashes)        | `u.hex`          | `u.to_hex()`        |
| Raw bytes              | `u.bytes`        | `u.to_bytes()`      |
| Nil UUID               | `uuid.UUID(int=0)` | `UUID.nil()`      |
| Version field          | `u.version`      | `u.version()`       |
| Variant field          | `u.variant`      | `u.variant()`       |
| SIMD storage           | No               | Yes                 |
| Vectorized hex encode  | No               | Yes                 |
| Batch generation       | No               | `uuid4_batch[N]()`  |

## Running Tests

```bash
pixi run tests        # run all test files
pixi run test-core    # UUID struct tests
pixi run test-v4      # v4 generation tests
pixi run test-v7      # v7 generation tests
pixi run test-simd-hex  # hex encode/decode tests
```

## Running Examples

```bash
pixi run example
```

## Modules

| Module         | Description                                            |
|----------------|--------------------------------------------------------|
| `uuid`         | Public re-exports: `UUID`, `uuid4`, `uuid7`, ...       |
| `uuid.core`    | `UUID` struct: storage, parse, format, equality, hash  |
| `uuid.v4`      | `uuid4()` and `uuid4_batch[N]()` random generation     |
| `uuid.v7`      | `uuid7()` time-ordered generation, timestamp extract   |
| `uuid.simd_hex`| SIMD hex encode/decode primitives                      |

## References

- [RFC 9562 – Universally Unique IDentifiers (UUIDs)](https://www.rfc-editor.org/rfc/rfc9562)
- [SIMD hex encoding (Richard Lupton)](https://richardlupton.com/posts/simd-hex/)
- [uuid_v4 (C++ SIMD)](https://github.com/crashoz/uuid_v4)
- [uuid-simd (Rust)](https://docs.rs/uuid-simd/latest/uuid_simd/)
- [fastuuid (Python/Rust)](https://github.com/fastuuid/fastuuid)

## License

[MIT](LICENSE)
