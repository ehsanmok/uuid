"""Fast UUID v4 and v7 generation for Mojo with SIMD-accelerated hex encoding.

`uuid` is a zero-dependency Mojo library for generating and parsing
Universally Unique Identifiers (UUIDs) per [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562).
All 16 UUID bytes are stored in a single `SIMD[DType.uint8, 16]` register,
and hex encoding/decoding uses vectorized SIMD arithmetic for maximum speed.

## Quick Start

```mojo
from uuid import UUID, uuid4, uuid7

# Generate a random UUID (version 4)
var id = uuid4()
print(id)            # e.g. "a8098c1a-f86e-11da-bd1a-00112444be1e"
print(id.version())  # 4
print(id.variant())  # 2 (RFC 9562)

# Generate a time-ordered UUID (version 7)
var id7 = uuid7()
print(id7.version())  # 7

# Parse from string
var parsed = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
print(parsed.to_hex())  # "550e8400e29b41d4a716446655440000"

# Nil UUID
var nil = UUID.nil()
print(nil.is_nil())  # True

# Batch generation (100 v4 UUIDs in one call)
var ids = uuid4_batch[100]()
```

## Supported UUID Versions

| Version | Function      | Description                                      |
|---------|---------------|--------------------------------------------------|
| v4      | `uuid4()`     | Fully random, RFC 9562 compliant                 |
| v7      | `uuid7()`     | Unix ms timestamp + random, monotonically sorted |
| nil     | `UUID.nil()`  | All-zero special-form UUID                       |

## Performance

All UUID bytes live in a single `SIMD[DType.uint8, 16]` register:

- **Hex encoding**: vectorized nibble extraction + branch-free select across all
  16 bytes simultaneously, interleaved via compile-time shuffle.
- **Parsing**: SIMD arithmetic on 32 hex characters in parallel.
- **v4 generation**: 2 calls to `random_ui64()` + 2 SIMD bit-mask operations.
- **v7 generation**: 1 `gettimeofday` syscall + `random_ui64()` + SIMD packing.

## UUID Format (RFC 9562)

```
xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx
         |    |    |
         |    |    +-- N: variant bits (high 2 bits of byte 8, = 10 for RFC)
         |    +------- M: version digit (4 or 7)
         +------------ timestamp (v7) or random (v4)
```

UUID v4 bit layout:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           random_a                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          random_b             |Ver|       random_c            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Var|                       random_d                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           random_e                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

UUID v7 bit layout:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        unix_ts_ms (high 32)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     unix_ts_ms (low 16)       |  ver  |       rand_a          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|var|                        rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           rand_b (cont)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

## API Reference

### UUID struct

| Method / Field                 | Description                                      |
|-------------------------------|--------------------------------------------------|
| `UUID.parse(s) raises -> UUID` | Parse from 36-char dashed string                |
| `UUID.nil() -> UUID`           | All-zero nil UUID                               |
| `String(u)` / `write_to`      | 36-char dashed string `xxxxxxxx-...-xxxx`       |
| `u.to_hex() -> String`         | 32-char hex string (no dashes)                  |
| `u.version() -> Int`           | Version field (4, 7, ...)                       |
| `u.variant() -> Int`           | Variant field (2 = RFC 9562)                    |
| `u.is_nil() -> Bool`           | True if all 128 bits are zero                   |
| `u == other` / `u != other`    | Equality comparison                             |
| `hash(u)`                      | Hash for use in sets / dicts                    |
| `u.to_bytes()`                 | Raw bytes as `InlineArray[UInt8, 16]`           |
| `u.bytes`                      | Direct `SIMD[DType.uint8, 16]` access           |

### Generation functions

| Function              | Description                                    |
|-----------------------|------------------------------------------------|
| `uuid4() -> UUID`     | Random v4 UUID (RFC 9562)                      |
| `uuid4_batch[N]()`    | N random v4 UUIDs in one call                  |
| `uuid7() -> UUID`     | Time-ordered v7 UUID with monotonicity         |
| `uuid7_extract_ms(u)` | Extract Unix ms timestamp from a v7 UUID       |

## Modules

| Module           | Description                                            |
|------------------|--------------------------------------------------------|
| uuid.core        | `UUID` struct: storage, parse, format, equality, hash  |
| uuid.v4          | `uuid4()` and `uuid4_batch[N]()` random generation     |
| uuid.v7          | `uuid7()` time-ordered generation, timestamp extract   |
| uuid.simd_hex    | SIMD hex encode/decode primitives                      |
"""

from .core import UUID
from .v4 import uuid4, uuid4_batch
from .v7 import uuid7, uuid7_extract_ms, V7Generator
from .simd_hex import hex_encode_16, hex_decode_32, nibble_to_hex
