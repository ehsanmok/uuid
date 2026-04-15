# uuid

[![CI](https://github.com/ehsanmok/uuid/actions/workflows/ci.yml/badge.svg)](https://github.com/ehsanmok/uuid/actions)
[![Docs](https://github.com/ehsanmok/uuid/actions/workflows/docs.yaml/badge.svg)](https://ehsanmok.github.io/uuid)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Fast UUID v4 and v7 generation for Mojo with SIMD-accelerated hex encoding.

All 16 UUID bytes live in a single `SIMD[DType.uint8, 16]` register. Hex
encoding processes all bytes simultaneously via vectorized nibble arithmetic
and a compile-time interleave shuffle, inspired by
[Richard Lupton's SIMD hex encoding](https://richardlupton.com/posts/simd-hex/).

## Quick Start

```mojo
from uuid import UUID, uuid4, uuid7

# Random UUID (version 4)
var id = uuid4()
print(id)             # "a8098c1a-f86e-11da-bd1a-00112444be1e"
print(id.version())   # 4
print(id.variant())   # 2  (RFC 9562)

# Time-ordered UUID (version 7), embeds Unix ms timestamp for natural sort
var t = uuid7()
print(t.version())    # 7
var ms = uuid7_extract_ms(t)

# Parse from a dashed string
var p = UUID.parse("550e8400-e29b-41d4-a716-446655440000")
print(p.to_hex())     # "550e8400e29b41d4a716446655440000"

# Nil UUID
var nil = UUID.nil()
print(nil.is_nil())   # True

# Batch generation: N v4 UUIDs in one call
var ids = uuid4_batch[100]()
```

## Installation

Add uuid to your project's `pixi.toml`:

```toml
[workspace]
channels = ["https://conda.modular.com/max-nightly", "conda-forge"]
preview = ["pixi-build"]

[dependencies]
uuid = { git = "https://github.com/ehsanmok/uuid.git", tag = "v0.1.0" }
```

Then run:

```bash
pixi install
```

Requires [pixi](https://pixi.sh) (pulls Mojo nightly automatically).

For the latest development version:

```toml
[dependencies]
uuid = { git = "https://github.com/ehsanmok/uuid.git", branch = "main" }
```

## v4 vs v7: When to Use Which

| Property                | v4 (random)               | v7 (time-ordered)           |
|-------------------------|---------------------------|-----------------------------|
| Uniqueness source       | Pure random               | Timestamp + random          |
| Sort order              | Random                    | Chronological               |
| Database index locality | Poor (random inserts)     | Excellent (append-friendly) |
| Predictability          | None                      | Timestamp is visible        |
| Best for                | General-purpose IDs       | Primary keys, audit logs    |

Both versions are monotonicity-safe: two `uuid7()` calls in the same millisecond
increment the `rand_a` counter to guarantee strict ordering.

## Example

```mojo
from uuid import UUID, uuid4, uuid4_batch, uuid7, uuid7_extract_ms

def main() raises:
    # Generate and format
    var id = uuid4()
    print("v4:", id)
    print("hex:", id.to_hex())
    print("bytes:", id.bytes)

    # Time-ordered
    var t = uuid7()
    print("v7:", t)
    print("timestamp ms:", uuid7_extract_ms(t))

    # Parse and round-trip
    var s = String(id)
    var parsed = UUID.parse(s)
    print("round-trip ok:", id == parsed)

    # Batch
    var batch = uuid4_batch[10]()
    for i in range(10):
        print(batch[i])
```

Run it:

```bash
pixi run example
```

## Performance

Benchmarks on Apple M-series (run `pixi run bench` to reproduce):

| Operation            | Approx. time |
|----------------------|--------------|
| `uuid4()` generate   | < 100 ns     |
| `uuid7()` generate   | < 150 ns     |
| `UUID.parse()`       | < 80 ns      |
| `String(UUID)`       | < 50 ns      |
| `uuid4_batch[100]`   | < 5 µs       |

Full API reference: [ehsanmok.github.io/uuid](https://ehsanmok.github.io/uuid)

## Development

```bash
pixi run tests          # all tests
pixi run test-core      # UUID struct
pixi run test-v4        # v4 generation
pixi run test-v7        # v7 generation
pixi run test-simd-hex  # hex encode/decode

pixi run bench          # throughput benchmarks
pixi run example        # run examples/example.mojo

pixi run -e dev docs    # build + serve API docs locally
```

## License

[MIT](LICENSE)
