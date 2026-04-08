"""Throughput benchmarks for the uuid library.

Measures performance of UUID generation, parsing, and formatting using the
standard `std.benchmark` harness with anti-optimization guards (`keep`,
`clobber_memory`).

Run with:

    mojo -I . benchmark/bench.mojo

or via pixi:

    pixi run bench

Expected throughput targets on a modern CPU:

    | Operation           | Target    |
    |---------------------|-----------|
    | uuid4() generate    | < 100 ns  |
    | uuid7() generate    | < 150 ns  |
    | UUID.parse()        | < 80 ns   |
    | String(uuid)        | < 50 ns   |
    | uuid4_batch[100]()  | < 5 us    |
"""

from std.benchmark import Bench, BenchConfig, BenchId, keep, clobber_memory
from uuid import UUID, uuid4, uuid4_batch, uuid7

comptime KNOWN_STR = "550e8400-e29b-41d4-a716-446655440000"


def main() raises:
    var bench = Bench(BenchConfig(max_iters=10_000))

    # =========================================================================
    # UUID v4 generation
    # =========================================================================

    @parameter
    @always_inline
    def bench_uuid4_gen() raises:
        var u = uuid4()
        keep(u.bytes)

    bench.bench_function[bench_uuid4_gen](BenchId("generate", "uuid4"))

    # =========================================================================
    # UUID v7 generation
    # =========================================================================

    @parameter
    @always_inline
    def bench_uuid7_gen() raises:
        var u = uuid7()
        keep(u.bytes)

    bench.bench_function[bench_uuid7_gen](BenchId("generate", "uuid7"))

    # =========================================================================
    # Batch v4 generation (100 at once)
    # =========================================================================

    @parameter
    @always_inline
    def bench_uuid4_batch() raises:
        clobber_memory()
        var batch = uuid4_batch[100]()
        keep(batch[0].bytes)

    bench.bench_function[bench_uuid4_batch](BenchId("generate", "uuid4_batch_100"))

    # =========================================================================
    # Parse from string
    # =========================================================================

    @parameter
    @always_inline
    def bench_parse() raises:
        clobber_memory()
        var u = UUID.parse(KNOWN_STR)
        keep(u.bytes)

    bench.bench_function[bench_parse](BenchId("parse", "UUID.parse"))

    # =========================================================================
    # Format to string
    # =========================================================================

    var fmt_uuid = uuid4()

    @parameter
    @always_inline
    def bench_format() raises:
        clobber_memory()
        var s = String(fmt_uuid)
        keep(s.as_bytes().unsafe_ptr())

    bench.bench_function[bench_format](BenchId("format", "String(UUID)"))

    # =========================================================================
    # to_hex (no dashes)
    # =========================================================================

    var hex_uuid = uuid4()

    @parameter
    @always_inline
    def bench_to_hex() raises:
        clobber_memory()
        var h = hex_uuid.to_hex()
        keep(h.as_bytes().unsafe_ptr())

    bench.bench_function[bench_to_hex](BenchId("format", "UUID.to_hex"))

    print(bench)
